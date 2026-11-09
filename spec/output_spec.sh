# shellcheck shell=bash

Describe "a process' output"
  BeforeEach 'setup_workdir'
  AfterEach 'cleanup_workdir'

  # The talker's log, without colors, once it has exited.
  talker_log () {
    wait_until 3 talker_exited || return 1
    sed 's/\x1b\[[0-9;]*m//g' "$(log_dir)/talker.log"
  }
  talker_exited () { [[ $(status_of talker) == Exited* ]]; }

  Describe 'without timestamps'
    BeforeEach 'start_server talker'

    It 'is logged with the process name prefixed, including stderr'
      When call talker_log
      The line 1 of output should match pattern 'talker *| to stdout'
      The line 2 of output should match pattern 'talker *| to stderr'
    End

    It 'keeps a last line without a trailing newline'
      When call talker_log
      The line 3 of output should match pattern 'talker *| no newline at the end'
      The lines of output should eq 3
    End
  End

  Describe 'with -t'
    BeforeEach 'start_server -t talker'

    It 'is logged with a timestamp prefixed'
      When call talker_log
      The line 1 of output should match pattern '[0-2][0-9]:[0-5][0-9]:[0-5][0-9] talker *| to stdout'
    End
  End
End
