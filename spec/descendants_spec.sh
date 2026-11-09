# shellcheck shell=bash

Describe 'stopping a process'
  start_family () {
    start_server family && wait_until 3 family_pids > /dev/null
  }
  BeforeEach 'setup_workdir' 'start_family'
  AfterEach 'cleanup_workdir'

  It 'starts the descendants this test relies on'
    When call family_gone
    The status should be failure
  End

  It 'kills its descendants on stop'
    stop_family () { bpm stop family > /dev/null && wait_until 3 family_gone; }
    When call stop_family
    The status should be success
  End

  It 'kills its descendants on stop -s KILL'
    stop_family () { bpm stop -s KILL family > /dev/null && wait_until 3 family_gone; }
    When call stop_family
    The status should be success
  End

  It 'kills its descendants on shutdown (Ctrl-C)'
    shutdown () { stop_server && wait_until 3 family_gone; }
    When call shutdown
    The status should be success
  End
End
