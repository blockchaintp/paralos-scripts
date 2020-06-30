#!/bin/bash
NAMESPACE=$1
FORMAT=$2

flag=0
KEY_LIST=

function get_public_keys {
  kubectl get configmap -n $NAMESPACE validator-public -o jsonpath='{.data.*}'  
}

if [ -z "$FORMAT" ] ; then
  for k in $(get_public_keys) ; do 
    echo $k
  done
elif [ "$FORMAT" = "json" ]; then
  keys=
  for k in $(get_public_keys) ; do 
    v=\"$k\";
    if [ -z "$keys" ]; then
      keys=$v
    else
      keys=$keys,$v
    fi
  done
  echo [$keys]
elif [ "$FORMAT" = "string" ]; then
  keys=
  for k in $(get_public_keys) ; do 
    v=$k;
    if [ -z "$keys" ]; then
      keys=$v
    else
      keys=$keys,$v
    fi
  done
  echo \"$keys\"
fi
