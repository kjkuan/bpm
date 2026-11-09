# shellcheck shell=bash

Describe 'the server shutting down on a signal'
  BeforeEach 'setup_workdir'
  AfterEach 'cleanup_workdir'

  procs_recorded () { test -s "$WORK/counter.pid" && test -s "$WORK/idle.pid"; }
  procs_gone () { pids_gone "$(cat "$WORK/counter.pid")" "$(cat "$WORK/idle.pid")"; }

  # Waits for the server ($1) to exit, then checks it shut down cleanly.
  shut_down_cleanly () {
    wait_until 8 server_gone "$1" || { echo 'server still running'; return 1; }
    wait_until 3 procs_gone || { echo 'processes still running'; return 1; }
    [[ $(cat "$WORK/counter.exit" 2>/dev/null) == done ]] || echo "counter's EXIT trap didn't run"
    [[ ! -e $WORK/.bpmfifo && ! -e $WORK/.bpmpid ]] || echo '.bpmfifo / .bpmpid left behind'
    echo checked
  }

  Describe 'sent to it'
    BeforeEach 'start_server counter idle && wait_until 3 procs_recorded'

    signal_server () {
      local pid
      pid=$(server_pid) || return 1
      kill -s "$1" "$pid"
      shut_down_cleanly "$pid"
    }

    It 'stops all processes on HUP'
      When call signal_server HUP
      The output should eq checked
    End

    It 'stops all processes on TERM'
      When call signal_server TERM
      The output should eq checked
    End
  End

  Describe 'when its terminal is closed'
    BeforeEach 'start_server_in_terminal counter idle && wait_until 3 procs_recorded'

    close_terminal () {
      local pid
      pid=$(server_pid) || return 1
      # Kill only the script process (holding the terminal), once verified.
      [[ $(ps -o args= -p "$SCRIPT_PID") == script* ]] || return 1
      kill -KILL "$SCRIPT_PID"
      shut_down_cleanly "$pid"
    }

    It 'stops all processes'
      When call close_terminal
      The output should eq checked
    End
  End
End
