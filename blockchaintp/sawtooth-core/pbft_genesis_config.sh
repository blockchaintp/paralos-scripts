#!/bin/bash -x
NAMESPACE=$1

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir -p /etc/sawtooth/genesis
source ${DIR}/tunables.include

flag=0
KEY_LIST=$(${DIR}/get_local_public_keys.sh $NAMESPACE json)

GOSSIP_TIME_TO_LIVE=${GOSSIP_TIME_TO_LIVE:-1}

if [ ! -r /etc/sawtooth/genesis/100-config.batch ]; then
  sawset proposal create -k /etc/sawtooth/keys/validator.priv \
    sawtooth.consensus.algorithm.name=pbft \
    sawtooth.consensus.algorithm.version=1.0 \
    sawtooth.consensus.pbft.members=$KEY_LIST \
    sawtooth.consensus.pbft.block_publishing_delay=${CONSENSUS_PBFT_BLOCK_PUBLISHING_DELAY_MS} \
    sawtooth.consensus.pbft.commit_timeout=${CONSENSUS_PBFT_COMMIT_TIMEOUT_MS} \
    sawtooth.consensus.pbft.forced_view_change_interval=${CONSENSUS_PBFT_FORCED_VIEW_CHANGE_INTERVAL_BLOCKS} \
    sawtooth.consensus.pbft.idle_timeout=${CONSENSUS_PBFT_IDLE_TIMEOUT_MS} \
    sawtooth.consensus.pbft.view_change_duration=${CONSENSUS_PBFT_VIEW_CHANGE_DURATION_MS} \
    sawtooth.publisher.max_batches_per_block=${PUBLISHER_MAX_BATCHES_PER_BLOCK} \
    sawtooth.validator.batch_injectors=${VALIDATOR_BATCH_INJECTORS} \
    sawtooth.gossip.time_to_live=${GOSSIP_TIME_TO_LIVE} \
    -o /etc/sawtooth/genesis/100-config.batch;
fi
