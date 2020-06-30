#!/bin/bash
mkdir -p /etc/sawtooth/genesis
source /usr/local/bin/tunables.include

GOSSIP_TIME_TO_LIVE=${GOSSIP_TIME_TO_LIVE:-15}

if [ ! -r /etc/sawtooth/genesis/100-config.batch ]; then
  sawset proposal create -k /etc/sawtooth/keys/validator.priv \
    sawtooth.consensus.algorithm=poet \
    sawtooth.poet.report_public_key_pem="$(cat /etc/sawtooth/simulator_rk_pub.pem)" \
    sawtooth.poet.valid_enclave_measurements=$(cat /etc/sawtooth/poet/poet-enclave-measurement) \
    sawtooth.poet.valid_enclave_basenames=$(cat /etc/sawtooth/poet/poet-enclave-basename) \
    sawtooth.poet.target_wait_time=${POET_TARGET_WAIT_TIME} \
    sawtooth.poet.initial_wait_time=${POET_INITIAL_WAIT_TIME} \
    sawtooth.poet.key_block_claim_limit=${POET_KEY_BLOCK_CLAIM_LIMIT} \
    sawtooth.poet.ztest_minimum_win_count=${POET_ZTEST_MINIMUM_WIN_COUNT} \
    sawtooth.publisher.max_batches_per_block=${PUBLISHER_MAX_BATCHES_PER_BLOCK} \
    sawtooth.validator.batch_injectors=${VALIDATOR_BATCH_INJECTORS} \
    sawtooth.gossip.time_to_live=${GOSSIP_TIME_TO_LIVE} \
    -o /etc/sawtooth/genesis/100-config.batch; 
fi
