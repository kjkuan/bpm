# shellcheck shell=bash

Describe 'bpm stop errors'
  BeforeEach 'setup_workdir' 'start_server counter idle'
  AfterEach 'cleanup_workdir'

  It 'rejects an unsupported signal and keeps running'
    When call bpm stop -s HUP counter
    The status should be failure
    The output should eq 'Only INT|TERM|KILL is allowed as a stop signal.'
    The value "$(server_pid)" should be present
    The value "$(status_of counter)" should eq running
  End

  It 'rejects -s without a signal and keeps running'
    When call bpm stop -s
    The status should be failure
    The output should eq 'Missing the SIGNAL argument for option: -s'
    The value "$(server_pid)" should be present
  End

  It 'rejects an unknown process name'
    When call bpm stop nosuch
    The status should be failure
    The output should eq 'Unknown process name: nosuch'
  End

  It 'reports a process that was not started'
    When call bpm stop fails
    The status should be success
    The output should eq 'Process fails was not started.'
  End
End
