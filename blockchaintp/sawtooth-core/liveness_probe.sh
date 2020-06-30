#!/bin/bash

RUN_DIR=${RUN_DIR:-/var/run/sawtooth}
SIGNALS_DIR=${RUN_DIR:-/var/run/signals}
LIVENESS_PROBE_ACTIVE=${LIVENESS_PROBE_ACTIVE:-false}
SAWTOOTH_LOG_DIR=${SAWTOOTH_LOG_DIR:-/var/log/sawtooth}
PBFT_LOG=${PBFT_LOG:-/var/lib/sawtooth/pbft.log}
FAIL_THRESHOLD=${FAIL_THRESHOLD:-10}
WAIT_FOR_VIEW=${WAIT_FOR_VIEW:-$(echo $RANDOM | cut -c1-2)}

SHORT_RANGE=${SHORT_RANGE:-1000}
LONG_RANGE=${LONG_RANGE:-10000}

EXIT_SIGNALS=${EXIT_SIGNALS:-block-info-tp}


function log {
  tstamp=$(date -Iminutes)
  echo "$tstamp" "$@" >> "${SAWTOOTH_LOG_DIR}/liveness.log"
  echo "$@"
}

function exit_successful {
  log This probe passes
  exit 0
}

function exit_failure {
  log This probe fails
  if [ "$LIVENESS_PROBE_ACTIVE" = "true" ]; then
    for signal in ${EXIT_SIGNALS}; do
      touch "${SIGNALS_DIR}/$signal"
    done
    exit 1
  else
    log But the probe is disabled
    for signal in ${EXIT_SIGNALS}; do
      log Would touch "${SIGNALS_DIR}/$signal"
    done
    exit 0
  fi
}

mkdir -p "${RUN_DIR}" || ( log "Failed to create ${RUN_DIR}" && exit_failure )
mkdir -p "${SIGNALS_DIR}" || ( log "Failed to create ${SIGNALS_DIR}" && exit_failure )

function get_last_seen_block() {
  tail -n "${LONG_RANGE}" "${SAWTOOTH_LOG_DIR}/validator-debug.log" |
    grep block_validator | grep "passed validation" |
    grep block_num | awk -F'block_num:' '{print $2}' |
    awk -F, '{print $1}' | tail -1 >"${RUN_DIR}/probe.new"
  cat "${RUN_DIR}/probe.new"
}

function safe_requesting_predecessors {
  local pred_requests;
  pred_requests=$(tail -n "${SHORT_RANGE}" "${SAWTOOTH_LOG_DIR}/validator-debug.log" |
                        grep -ic "request missing predecessor" ) 
  local requesting_threshold;
  requesting_threshold=$((SHORT_RANGE / 2))
  if [ $pred_requests -ge $requesting_threshold ]; then
    log "Predecessors were recently requested"
    return 1
  fi
  return 0
}

function safe_pbft_status() {
  if [ -r "$PBFT_LOG" ]; then
    grep -q "\"Finishing\":true" "$PBFT_LOG" &&
      log PBFT is currently in catch-up mode &&
      return 0
    log PBFT is not currently catching up
    return 1
  else
    log PBFT consensus has not started yet
    return 0
  fi
  log This node is not running PBFT
  return 0
}

function get_last_view {
  if [ -r "${RUN_DIR}/last.view" ]; then
    view=$(cat "${RUN_DIR}/last.view")
    if [ -z "$view" ]; then
      echo 0
    else
      echo "$view"
    fi
  else 
    echo 0
  fi
}

function get_current_view {
  awk -FViewChanging\": '{print $2}' "${PBFT_LOG}" | \
      awk -F"}" '{print $1}'
}

function set_last_view {
  local view=$1
  echo "$view" > "${RUN_DIR}/last.view"
}

function get_now {
  date +%s
}

function get_last_view_time {
  if [ -r "${RUN_DIR}/last.view.time" ]; then
    cat "${RUN_DIR}/last.view.time"
  else 
    get_now
  fi
}

function set_last_view_time {
  local time=$1
  echo "$time" > "${RUN_DIR}/last.view.time"
}

function is_view_changing() {
  now=$(get_now)
  grep -q "\"mode\":{\"ViewChanging" "$PBFT_LOG"
  ERR=$?
  if [ $ERR -eq 0 ]; then
    log This node is currently in ViewChanging mode
    current_view=$(get_current_view)
    last_view=$(get_last_view)
    was=$(get_last_view_time)
    too_long=$((was + WAIT_FOR_VIEW))
    if [ "$current_view" -ne "$last_view" ]; then
      log Current view is different from last check
      set_last_view_time "$now"
      set_last_view "$current_view"
      return 0
    else
      if [ "$now" -gt "$too_long" ]; then
        log This node has been trying to change to this view for too long
        return 1
      else
        return 0
      fi
    fi
  else
    set_last_view 0
    set_last_view_time "$now"
    log Not in ViewChanging mode
    return 2
  fi
}

function get_last_pbft_commit() {
  if [ -r "${PBFT_LOG}" ]; then
    touch "${RUN_DIR}/pbft_seq.last"
    awk -Fseq_num\": '{print $NF}' "${PBFT_LOG}" |
      awk -F, '{print $1}' > "${RUN_DIR}/pbft_seq.new"
    cat "${RUN_DIR}/pbft_seq.new"
  fi
}

function check_critical_errors() {
  grep -v "Cannot create wait certificate because timer has timed out" "${SAWTOOTH_LOG_DIR}/validator-error.log" |
    grep -v "claiming blocks too frequently." |
    grep -v "Create new registration" |
    grep ERROR
  found=$?
  if [ $found -eq 0 ]; then
    log Found significant errors in the log, errors will follow
    cat "${SAWTOOTH_LOG_DIR}/validator-error.log"
    return 1
  else
    return 0
  fi
}

function get_last_probe {
  cat "${RUN_DIR}/probe.last"
}

function set_last_probe {
  local seq=$1
  echo "$seq" > "${RUN_DIR}/probe.last"
}

function get_fail_count {
  if [ -r "${RUN_DIR}/probe.count" ]; then
    cat "${RUN_DIR}/probe.count"
  else 
    echo 0
  fi
}

function get_last_pbft_seq {
  if [ -r "${PBFT_LOG}" ]; then
    cat "${RUN_DIR}/pbft_seq.last"
  fi
}

function set_last_pbft_seq {
  local seq=$1
  echo "$seq" > "${RUN_DIR}/pbft_seq.last"
}

function set_probe_count {
  local count=$1
  echo "$count" > "${RUN_DIR}/probe.count"
}

log ====== BEGIN PROBE ======
check_critical_errors || exit_failure
safe_requesting_predecessors 
if [ $? -ne 0 ]; then
  set_probe_count 0
  exit_successful
fi
LAST_PROBE=$(get_last_probe)
THIS_PROBE=$(get_last_seen_block)
LAST_PBFT_SEQ=$(get_last_pbft_seq)
THIS_PBFT_SEQ=$(get_last_pbft_commit)
set_last_pbft_seq "$THIS_PBFT_SEQ"

FAIL_COUNT=$(get_fail_count)

if [ "$THIS_PROBE" = "$LAST_PROBE" ]; then
  if [ -r "${PBFT_LOG}" ]; then
    safe_pbft_status && 
      set_probe_count 0 && 
      log This node is in a safe status, probe passes &&
      exit_successful

    is_view_changing 
    ERR=$?
    if [ $ERR -ge 1 ]; then
      log Node is either in ViewChanging too long or has not made significant progress
      if [ "$THIS_PBFT_SEQ" = "$LAST_PBFT_SEQ" ]; then
        log And there have not been recent commits
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
    fi
  else
    log There have not been recent commits
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  log "Current probe status follows:"
  log "FAIL_COUNT=$FAIL_COUNT LAST_PROBE=$LAST_PROBE THIS_PROBE=$THIS_PROBE"
  log "THIS_PBFT_SEQ=$THIS_PBFT_SEQ LAST_PBFT_SEQ=$LAST_PBFT_SEQ"
  set_probe_count $FAIL_COUNT
  if [ $FAIL_COUNT -gt "$FAIL_THRESHOLD" ]; then
    log "Exceeded FAIL_COUNT threshold=${FAIL_THRESHOLD} failures=${FAIL_COUNT}"
    exit_failure
  fi
else
  set_probe_count 0
fi
set_last_probe "$THIS_PROBE"
exit_successful
