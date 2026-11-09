# shellcheck shell=bash

Describe 'bpm stop'
  BeforeEach 'setup_workdir' 'start_server counter idle'
  AfterEach 'cleanup_workdir'

  It 'stops a process with TERM by default'
    When call bpm stop counter
    The status should be success
    The output should match pattern 'Process counter (*) stopped.'
    The value "$(status_of counter)" should eq 'Exited (143)'
  End

  It 'stops a process with the given signal'
    When call bpm stop -s int counter
    The status should be success
    The output should match pattern 'Process counter (*) stopped.'
    The value "$(status_of counter)" should eq 'Exited (130)'
  End

  It 'stops a process with KILL'
    When call bpm stop -s KILL idle
    The status should be success
    The output should match pattern 'Process idle (*) stopped.'
    The value "$(status_of idle)" should eq 'Exited (137)'
  End

  It "keeps a process' last lines"
    last_line_logged () { grep -q 'counter done' "$(log_dir)/counter.log"; }
    stop_and_check () { bpm stop counter > /dev/null && wait_until 3 last_line_logged; }
    When call stop_and_check
    The status should be success
  End
End
