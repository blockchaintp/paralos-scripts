#!/bin/bash
NAMESPACE=$1
NETWORK_NAME=$2
POD_NAME=$3
POD_IP=$4
NODE_NAME=$5

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export SEEDS=
export PEERS=
export MY_EXTERNAL_IP=

export DELAY=0

function get_local_pods {
  kubectl -n ${NAMESPACE} get pod -l app=${NETWORK_NAME}-validator --no-headers=true
}

declare -a host_list
for node in `kubectl --namespace ${NAMESPACE} get \
              pod -l app=${NETWORK_NAME}-validator \
              -o jsonpath='{ $.items[*].spec.nodeName }'|sort`; do
    host_list+=($node)
done

host_list_length=${#host_list[@]}
peer_count=0
index=0
MY_IP=
MAX_PEERS=$(( $host_list_length / 2 ))

while [ $peer_count -lt $MAX_PEERS  ]; do
    node=${host_list[$index]}
    if [ "$node" != "${NODE_NAME}" ]; then
      if [ ! -z "${MY_IP}" ]; then
        echo $node $index $peer_count
        export SEEDS="--seeds tcp://$node:8800 $SEEDS";
        export PEERS="--peers tcp://$node:8800 $PEERS";
        peer_count=$(( $peer_count +1 ))
        export DELAY=$(( $DELAY + 1 ))
      fi
    else
      export MY_IP=${POD_IP}
    fi
    index=$(( $index + 1 ))
    if [ $index -ge $host_list_length ]; then
      index=0
    fi
done

SET_GENESIS_NODE=${host_list[0]}

function get_genesis_node {
  kubectl -n ${NAMESPACE} get configmap genesis -o jsonpath='{.data.node}'
}

GENESIS_NODE=$(get_genesis_node)
while [ -z "$GENESIS_NODE" ]; do
  sleep `echo $RANDOM|cut -c1-2`
  GENESIS_NODE=$(get_genesis_node)
  if [ -z "$GENESIS_NODE" ]; then
    ${DIR}/upsert_cm.sh genesis node $SET_GENESIS_NODE
  fi
done

for node in `kubectl --namespace ${NAMESPACE} get \
              pod -l app=${NETWORK_NAME}-validator \
              -o jsonpath='{ $.items[*].spec.nodeName }'|sort`; do
  ip=`kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="ExternalIP")].address }' \
        -l kubernetes.io/role=node -l kubernetes.io/hostname=${node}`
  if [ "${NODE_NAME}" = "${node}" ]; then
    export MY_EXTERNAL_IP=$ip
    echo External IP Address is $MY_EXTERNAL_IP
  fi
done

${DIR}/upsert_cm.sh validator-public $NODE_NAME $(cat /etc/sawtooth/keys/validator.pub)

GENESIS_NODE=$(get_genesis_node)

if [ "$GENESIS_NODE" = $NODE_NAME ]; then
  export RUN_GENESIS=1
else
  export RUN_GENESIS=0
fi

if [ $RUN_GENESIS -eq 1 ]; then
  if [ ! -r /etc/sawtooth/initialized ]; then
    PODCOUNT=`get_local_pods | wc -l`
    KEYCOUNT=`${DIR}/get_local_public_keys.sh $NAMESPACE | wc -l`
    while [ "$PODCOUNT" != "$KEYCOUNT" ]; do
      sleep 5
      PODCOUNT=`get_local_pods | wc -l`
      KEYCOUNT=`${DIR}/get_local_public_keys.sh $NAMESPACE | wc -l`
    done
  fi
fi