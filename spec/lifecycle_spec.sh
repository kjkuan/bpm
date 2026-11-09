# shellcheck shell=bash

Describe 'bpm process lifecycle'
  BeforeEach 'setup_workdir'
  AfterEach 'cleanup_workdir'

  Describe 'stop without names'
    BeforeEach 'start_server counter idle'

    It 'stops only the running processes'
      When call bpm stop
      The status should be success
      The line 1 of output should match pattern 'Process counter (*) stopped.'
      The line 2 of output should match pattern 'Process idle (*) stopped.'
      The lines of output should eq 2
    End

    It 'prints nothing when there is nothing to stop'
      stop_twice () { bpm stop > /dev/null && bpm stop; }
      When call stop_twice
      The status should be success
      The output should eq ''
    End
  End

  Describe 'processes ending on their own'
    BeforeEach 'start_server fails selfterm selfkill'

    It 'records and reports their exit statuses'
      all_exited () { has_exited fails && has_exited selfterm && has_exited selfkill; }
      When call wait_until 5 all_exited
      The status should be success
      The value "$(status_of fails)" should eq 'exited (3)'
      The value "$(status_of selfterm)" should eq 'killed (SIGTERM)'
      The value "$(status_of selfkill)" should eq 'killed (SIGKILL)'
      The value "$(server_out)" should match pattern '*Process fails (*) exited (3).*'
      The value "$(server_out)" should match pattern '*Process selfterm (*) was killed by SIGTERM.*'
      The value "$(server_out)" should match pattern '*Process selfkill (*) was killed by SIGKILL.*'
    End
  End

  Describe 'shutting down (Ctrl-C)'
    BeforeEach 'start_server counter idle'

    It 'stops all processes, shows their last lines, and cleans up'
      count () { server_out | grep -c -- "$1"; }
      When call stop_server
      The status should be success
      The value "$(count "counter done")" should eq 1
      The value "$(count "Process counter (.*) stopped.")" should eq 1
      The value "$(count "Process idle (.*) stopped.")" should eq 1
      The value "$(count "was killed\|exited (\|was terminated")" should eq 0
      The value "$(count "^0$")" should eq 0
      The path "$WORK/.bpmfifo" should not be exist
      The path "$WORK/.bpmpid" should not be exist
    End
  End
End
