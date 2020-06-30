#!/bin/bash
NAMESPACE=$1

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir -p /etc/sawtooth/genesis
source ${DIR}/tunables.include

flag=0
KEY_LIST=$(${DIR}/get_local_public_keys.sh $NAMESPACE json)

GOSSIP_TIME_TO_LIVE=${GOSSIP_TIME_TO_LIVE:-1}

if [ ! -r /etc/sawtooth/genesis/100-config.batch ]; then
  sawset proposal create -k /etc/sawtooth/keys/validator.priv \
    sawtooth.consensus.algorithm.name=raft \
    sawtooth.consensus.algorithm.version=0.1 \
    sawtooth.consensus.raft.peers=$KEY_LIST \
    sawtooth.consensus.raft.period=${CONSENSUS_RAFT_PERIOD_MS} \
    sawtooth.consensus.raft.election_tick=${CONSENSUS_RAFT_ELECTION_TICK} \
    sawtooth.consensus.raft.heartbeat_tick=${CONSENSUS_RAFT_HEARTBEAT_TICK} \
    sawtooth.publisher.max_batches_per_block=${PUBLISHER_MAX_BATCHES_PER_BLOCK} \
    sawtooth.validator.batch_injectors=${VALIDATOR_BATCH_INJECTORS} \
    sawtooth.gossip.time_to_live=${GOSSIP_TIME_TO_LIVE} \
    -o /etc/sawtooth/genesis/100-config.batch; 
fi
