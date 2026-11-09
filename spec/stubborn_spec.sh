# shellcheck shell=bash

Describe 'stopping a process that ignores TERM'
  start_stubborn () {
    BPM_STOP_TIMEOUT=1 start_server stubborn idle &&
      wait_until 3 test -s "$WORK/stubborn.pid"
  }
  BeforeEach 'setup_workdir' 'start_stubborn'
  AfterEach 'cleanup_workdir'

  stubborn_gone () { pids_gone "$(cat "$WORK/stubborn.pid")"; }

  It 'kills it after the grace period'
    When call bpm stop stubborn
    The status should be success
    The output should match pattern "Process stubborn (*) didn't stop within 1s; killed it."
    The value "$(status_of stubborn)" should eq 'Exited (137)'
    The value "$(stubborn_gone && echo gone)" should eq gone
  End

  It 'keeps the server responsive'
    stop_then_list () { bpm stop stubborn > /dev/null; bpm list; }
    When call stop_then_list
    The status should be success
    The output should include 'idle'
  End

  It 'does not hold up shutdown (Ctrl-C)'
    shutdown () { stop_server && ! server_pid > /dev/null && stubborn_gone; }
    When call shutdown
    The status should be success
  End
End
