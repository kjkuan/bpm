# shellcheck shell=bash

Describe 'bpm list (with a server)'
  BeforeEach 'setup_workdir' 'start_server counter idle' 'bpm stop idle > /dev/null'
  AfterEach 'cleanup_workdir'

  row_of () { bpm list | grep "^$1 "; }

  It 'has a header'
    When call bpm list
    The status should be success
    The line 1 of output should match pattern 'NAME *STATUS *PID *STARTED'
  End

  It 'shows a running process with its PID, start time, and how long ago'
    When call row_of counter
    The output should match pattern "counter *running *$(pid_of counter) *[0-2][0-9]:[0-5][0-9]:[0-5][0-9], [0-9]*s ago"
  End

  It 'shows how a stopped process ended, without "ago"'
    When call row_of idle
    The output should match pattern "idle *killed (SIGTERM) *[0-9]* *[0-2][0-9]:[0-5][0-9]:[0-5][0-9]"
    The output should not include 'ago'
  End

  It 'shows a process that was not started'
    When call row_of fails
    The output should match pattern 'fails *not started *- *-'
  End
End
