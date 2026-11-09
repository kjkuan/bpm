# shellcheck shell=bash

Describe 'bpm logs'
  BeforeEach 'setup_workdir' 'start_server counter idle'
  AfterEach 'cleanup_workdir'

  defined_names () { sed -n 's|^Proc/\([a-z]*\) .*|\1|p' "$WORK/Procfile.sh" | sort; }
  all_log_paths () { defined_names | sed "s|.*|$(log_dir)/&.log|"; }

  It "prints the named processes' log paths with -p"
    When call bpm logs -p counter idle
    The status should be success
    The line 1 of output should eq "$(log_dir)/counter.log"
    The line 2 of output should eq "$(log_dir)/idle.log"
    The lines of output should eq 2
  End

  It "prints all processes' log paths with -p and no names"
    When call bpm logs -p
    The status should be success
    The output should eq "$(all_log_paths)"
  End

  It 'rejects an unknown process name'
    When call bpm logs -p counter nosuch
    The status should be failure
    The output should eq 'Unknown process name: nosuch'
  End

  It 'follows the logs with BPM_LOG_VIEWER'
    view_counter_log () { BPM_LOG_VIEWER='grep -m1 -o tick' bpm logs counter; }
    When call view_counter_log
    The status should be success
    The output should eq tick
  End
End
