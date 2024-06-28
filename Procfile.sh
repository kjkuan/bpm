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
