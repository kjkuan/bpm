# shellcheck shell=bash
#
# Helpers for testing bpm. Each example gets its own work directory (so its
# own .bpmfifo / .bpmpid) with the fixture Procfile below.

# Set BPM_UNDER_TEST to test another copy of bpm, e.g., an older version.
BPM=${BPM_UNDER_TEST:-$SHELLSPEC_PROJECT_ROOT/bpm}

# Warnings from bpm re-executing itself as `bash -i` without a terminal.
BPM_NOISE='cannot set terminal process group|no job control in this shell'

setup_workdir () {
    WORK=$(mktemp -d "${SHELLSPEC_TMPBASE:-${TMPDIR:-/tmp}}/bpm-spec.XXXXXX")
    cat > "$WORK/Procfile.sh" <<'EOF'
Proc/counter () {
    echo $BASHPID > counter.pid
    trap 'echo "counter done"; echo done > counter.exit' EXIT
    while :; do echo tick; sleep 0.2; done
}
Proc/idle () { echo $BASHPID > idle.pid; sleep 300; }
Proc/fails () { sleep 0.3; echo failing; exit 3; }
Proc/selfterm () { sleep 0.3; kill -TERM $BASHPID; sleep 5; }
Proc/selfkill () { sleep 0.3; kill -KILL $BASHPID; }
Proc/talker () {
    echo 'to stdout'
    echo 'to stderr' >&2
    printf 'no newline at the end'
}
Proc/stubborn () {
    trap '' TERM  # (inherited by its children too)
    echo $BASHPID > stubborn.pid
    while :; do sleep 0.2; done
}
Proc/where () { pwd; }
Proc/funcs () {
    # Any functions other than Proc/* ones, and whether Proc/where is callable.
    declare -F | cut -d' ' -f3 | grep -v '^Proc/' || echo none
    Proc/where > /dev/null && echo 'Proc/where callable'
}
Proc/family () {
    # A child, and a grandchild (in a nested subshell), all recorded.
    sleep 300 & echo $! >> family.pids
    ( sleep 300 & echo $! >> family.pids; echo $BASHPID >> family.pids; wait ) &
    echo $BASHPID >> family.pids
    wait
}
EOF
}

# The PIDs Proc/family recorded, once all four are in.
family_pids () {
    [[ $(wc -l < "$WORK/family.pids" 2>/dev/null) == 4 ]] && cat "$WORK/family.pids"
}

# Whether none of the given PIDs is still running (zombies count as gone).
pids_gone () {
    local pid stat
    for pid; do
        stat=$(ps -o stat= -p "$pid" 2>/dev/null) || continue
        [[ $stat == Z* ]] || return 1
    done
}

family_gone () { pids_gone $(cat "$WORK/family.pids"); }

cleanup_workdir () {
    kill_server
    kill_leftover_procs
    rm -rf "$WORK"
}

# Quickly gets rid of the server, if any, for cleaning up after an example:
# stops its processes (including ones started by clients, which
# kill_leftover_procs doesn't know about), then kills it, skipping its
# graceful shutdown (which waits a second for tail). kill_leftover_procs
# then cleans up its tail and log directory.
kill_server () {
    local pid
    if pid=$(server_pid); then
        bpm stop > /dev/null 2>&1
        kill -KILL "$pid" 2>/dev/null
        wait_until 3 server_gone "$pid"
    fi
    stop_server_timeout
}

# Runs bpm in the work directory, minus the job-control noise on stderr.
# Commands normally return right away; the timeout only guards against a
# client blocking on the FIFO forever (e.g., when testing older versions).
# NOTE: -k is needed since bpm runs as an interactive bash, which ignores the
#       TERM signal that timeout sends first.
bpm () {
    local rc
    (cd "$WORK" && timeout -k 1 "${BPM_CMD_TIMEOUT:-3}" "$BPM" "$@") 2> "$WORK/.stderr"
    rc=$?
    grep -Ev "$BPM_NOISE" "$WORK/.stderr" >&2
    return $rc
}

# wait_until TIMEOUT_SECS COMMAND...: polls COMMAND until it succeeds.
wait_until () {
    local tries=$(( $1 * 10 )); shift
    until "$@"; do
        (( tries-- > 0 )) || return 1
        sleep 0.1
    done
}

# (tr: output from a server run in a terminal has CRLF line endings.)
server_out () { grep -Ev "$BPM_NOISE" "$WORK/server.out" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r'; }
server_has () { server_out | grep -qF -- "$1"; }
log_dir () { server_out | sed -n 's/^Logging to \(.*\) \.\.\.$/\1/p'; }

# start_server [START ARGS...]: starts a bpm server in the background,
# logging to $WORK/server.out, and waits until it accepts commands.
# Set SERVER_CWD to start it from another directory (with -f pointing to
# $WORK/Procfile.sh).
start_server () {
    local opts=()
    [[ ! ${SERVER_CWD:-} ]] || opts=(-f "$WORK/Procfile.sh")
    (cd "${SERVER_CWD:-$WORK}" && exec timeout -k 1 60 "$BPM" "${opts[@]}" start "$@") \
        > "$WORK/server.out" 2>&1 &
    SERVER_TIMEOUT_PID=$!  # the timeout process (the subshell exec'ed it)
    disown "$SERVER_TIMEOUT_PID"  # no "Killed" job notices if we kill it
    # Wait for the server's own FIFO; a stale one may already be there.
    # On failure, clean up here: AfterEach doesn't run when a BeforeEach
    # fails, and a leftover server would keep shellspec waiting on it.
    if ! wait_until 5 server_ready; then
        echo "start_server: bpm server didn't come up" >&2
        stop_server_timeout
        kill_leftover_procs
        return 1
    fi
    bpm list > /dev/null
}

# start_server_in_terminal [START ARGS...]: like start_server, but runs the
# server in a pseudo-terminal, via script (whose PID is in SCRIPT_PID; killing
# it closes the terminal).
start_server_in_terminal () {
    script -qfec "cd '$WORK' && exec '$BPM' start $*" /dev/null \
        > "$WORK/server.out" 2>&1 < /dev/null &
    SCRIPT_PID=$!
    disown "$SCRIPT_PID"
    wait_until 5 server_ready
}

server_ready () { server_pid > /dev/null && test -p "$WORK/.bpmfifo"; }

# The server's PID, if one is running for $WORK.
server_pid () {
    local pid
    pid=$(cat "$WORK/.bpmpid" 2>/dev/null) || return 1
    [[ $pid =~ ^[0-9]+$ ]] || return 1
    ps -o args= -p "$pid" 2>/dev/null | grep -q 'bash --noediting.*bpm' || return 1
    echo "$pid"
}

server_gone () { ! kill -0 "$1" 2>/dev/null; }

# Stops the server like Ctrl-C does, and waits for it to exit. If the server
# can't be found via .bpmpid (e.g., it never got that far, or it's a bpm
# version without one), falls back to killing the timeout wrapping it, which
# kills the server too, so that no server outlives the example.
stop_server () {
    local pid
    if pid=$(server_pid); then
        kill -INT "$pid"
        wait_until 5 server_gone "$pid" || kill -KILL "$pid" 2>/dev/null
    fi
    stop_server_timeout
}

stop_server_timeout () {
    local pid=${SERVER_TIMEOUT_PID:-}
    [[ $pid =~ ^[0-9]+$ ]] || return 0
    ps -o args= -p "$pid" 2>/dev/null | grep -q "^timeout -k 1 60 $BPM " || return 0
    # timeout passes TERM on to bpm, which ignores it, then KILLs it a second
    # later and exits.
    kill -TERM "$pid" 2>/dev/null
    wait_until 3 server_gone "$pid" || kill -KILL "$pid" 2>/dev/null
}

# Cleans up after a server that didn't shut down properly (e.g., after a
# failed test, or one that was killed):
#  - kills the process groups bpm reported starting (bpm makes each process'
#    PID its group ID), even if their leaders are gone, but never our own;
#  - kills its log-following tail and removes its log directory.
kill_leftover_procs () {
    local pid mypgid dir
    mypgid=$(ps -o pgid= -p $$ | tr -d ' ')
    [[ -f $WORK/server.out ]] || return 0
    for pid in $(server_out | sed -n 's/^Started .* (\([0-9]*\))$/\1/p'); do
        [[ $pid =~ ^[0-9]+$ && $pid != "$mypgid" ]] || continue
        pgrep -g "$pid" > /dev/null && kill -KILL -- "-$pid" 2>/dev/null
    done
    dir=$(log_dir)
    if [[ $dir == "${TMPDIR:-/tmp}"/tmp.* && -d $dir ]]; then
        pkill -KILL -f "^tail -qF $dir/" 2>/dev/null
        rm -rf "$dir"
    fi
    return 0
}

# status_of NAME / pid_of NAME: prints the STATUS / PID column of NAME from
# `bpm list` (whose columns are separated by at least two spaces).
status_of () { bpm list | awk -F '  +' -v n="$1" '$1 == n { print $2 }'; }
pid_of () { bpm list | awk -F '  +' -v n="$1" '$1 == n { print $3 }'; }

status_is () { [[ $(status_of "$1") == "$2" ]]; }

# Whether the process NAME was started and has exited (or been killed).
has_exited () { [[ $(status_of "$1") == @(exited|killed)* ]]; }
