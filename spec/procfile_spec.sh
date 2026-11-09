# shellcheck shell=bash

Describe "a process' working directory"
  BeforeEach 'setup_workdir'
  AfterEach 'cleanup_workdir'

  # Where Proc/where ran, from its log, once it has exited.
  where_ran () {
    wait_until 3 where_exited || return 1
    sed 's/\x1b\[[0-9;]*m//g' "$(log_dir)/where.log" | sed 's/^where *| //'
  }
  where_exited () { [[ $(status_of where) == Exited* ]]; }

  It "is the Procfile's directory, even when bpm is started elsewhere"
    start_elsewhere () {
      mkdir "$WORK/elsewhere"
      SERVER_CWD=$WORK/elsewhere start_server where
    }
    BeforeCall 'start_elsewhere'
    When call where_ran
    The output should eq "$WORK"
  End

  It 'is where the Procfile cd-ed to, relative to its own directory'
    setup_cd () {
      mkdir -p "$WORK/sub" "$WORK/elsewhere/sub"
      sed -i '1i cd sub' "$WORK/Procfile.sh"
      SERVER_CWD=$WORK/elsewhere start_server where
    }
    BeforeCall 'setup_cd'
    When call where_ran
    The output should eq "$WORK/sub"
  End
End
