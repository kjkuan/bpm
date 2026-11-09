# shellcheck shell=bash

Describe 'log line colors'
  BeforeEach 'setup_workdir'
  AfterEach 'cleanup_workdir'

  talker_done () { has_exited talker; }
  # Whether the talker's log has color escape sequences, once it's exited.
  talker_log_colored () {
    wait_until 3 talker_done || return 2
    grep -q $'\e\\[38;5;' "$(log_dir)/talker.log"
  }

  It "aren't used when the server's output isn't a terminal"
    BeforeCall 'start_server talker'
    When call talker_log_colored
    The status should eq 1
  End

  It 'are used when it is'
    BeforeCall 'start_server_in_terminal talker'
    When call talker_log_colored
    The status should eq 0
  End

  It "aren't used, even then, with NO_COLOR set"
    BeforeCall 'NO_COLOR=1 start_server_in_terminal talker'
    When call talker_log_colored
    The status should eq 1
  End
End
