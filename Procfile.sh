# An example Procfile.sh; see "Procfile.sh" in README.md for the details.
#
# Each Proc/NAME function defines a process. Only these functions are kept from
# this file, so each must be self-contained: define (or source) what it needs
# inside the function. Processes start in this file's directory.
#
# Top-level commands run every time bpm runs; print messages to stderr, as
# stdout is discarded:
#
#     echo "Loading $BASH_SOURCE" >&2

Proc/p1 () {
    local i=0
    trap 'echo "Stopped counting from p1"' EXIT
    while true; do echo "..... $((i++))"; sleep 1.5; done
}

Proc/p2 () { sleep 3600; }

Proc/p3 () {
    echo "Faking a failed process ($$) ..."
    sleep 5
    echo "process failed :("
    exit 1
}
