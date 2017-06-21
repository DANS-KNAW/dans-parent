#@IgnoreInspection BashAddShebang

log_action_start() {
    local MESSAGE=$1
    echo -n "$MESSAGE..."
}

log_action_ok() {
    echo "OK."
}

log_script_start() {
    local PHASE=$1
    local NUMBER_OF_INSTALLATIONS=$2
    echo "$PHASE: START (Number of current installations: $NUMBER_OF_INSTALLATIONS)"
}

log_script_done() {
    local PHASE=$1
    echo "$PHASE: DONE"
}
