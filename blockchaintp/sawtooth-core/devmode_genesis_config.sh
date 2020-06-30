#!/bin/bash
mkdir -p /etc/sawtooth/genesis
source /usr/local/bin/tunables.include

GOSSIP_TIME_TO_LIVE=${GOSSIP_TIME_TO_LIVE:-1}

if [ ! -r /etc/sawtooth/genesis/100-config.batch ]; then
  sawset proposal create -k /etc/sawtooth/keys/validator.priv \
    sawtooth.consensus.algorithm=devmode \
    sawtooth.consensus.algorithm.name=Devmode \
    sawtooth.consensus.algorithm.version=0.1 \
    sawtooth.publisher.max_batches_per_block=${PUBLISHER_MAX_BATCHES_PER_BLOCK} \
    sawtooth.validator.batch_injectors=${VALIDATOR_BATCH_INJECTORS} \
    sawtooth.gossip.time_to_live=${GOSSIP_TIME_TO_LIVE} \
    -o /etc/sawtooth/genesis/100-config.batch; 
fi

