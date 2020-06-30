#!/bin/bash
NAMESPACE=$1

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

keys=$(${DIR}/get_local_public_keys.sh ${NAMESPACE} string)
if [ ! -r /etc/sawtooth/genesis/300-identity.batch ]; then
  sawset proposal create -k /etc/sawtooth/keys/validator.priv \
    sawtooth.identity.allowed_keys=$keys \
    -o /etc/sawtooth/genesis/300-identity.batch; 
fi
