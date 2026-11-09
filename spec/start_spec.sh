# shellcheck shell=bash

Describe 'bpm start (with a server)'
  BeforeEach 'setup_workdir' 'start_server counter idle'
  AfterEach 'cleanup_workdir'

  It 'lists the started processes as running'
    When call status_of counter
    The output should eq running
  End

  It 'refuses to start a process that is already running'
    When call bpm start counter
    The status should be success
    The output should match pattern 'Process counter (*) was already started; please stop it first.'
  End

  It 'restarts a stopped process'
    restart () { bpm stop counter > /dev/null && bpm start counter; }
    When call restart
    The status should be success
    The output should match pattern 'Started counter (*)'
    The value "$(status_of counter)" should eq running
  End
End
