# shellcheck shell=bash

Describe 'bpm restart'
  BeforeEach 'setup_workdir' 'start_server counter idle'
  AfterEach 'cleanup_workdir'

  pid_of () { bpm list | awk -v n="$1" '$1 == n { sub(/^pid=/, "", $2); print $2 }'; }

  It 'stops and starts a running process again'
    old_pid=
    restart_counter () { old_pid=$(pid_of counter); bpm restart counter; }
    When call restart_counter
    The status should be success
    The line 1 of output should eq "Process counter ($old_pid) stopped."
    The line 2 of output should match pattern 'Started counter (*)'
    The lines of output should eq 2
    The value "$(status_of counter)" should eq running
    The value "$(pid_of counter)" should not eq "$old_pid"
  End

  It 'starts a process that is not running'
    restart_stopped () { bpm stop idle > /dev/null && bpm restart idle; }
    When call restart_stopped
    The status should be success
    The output should match pattern 'Started idle (*)'
    The value "$(status_of idle)" should eq running
  End

  It 'restarts only the running processes when no names are given'
    restart_all () { bpm stop idle > /dev/null && bpm restart; }
    When call restart_all
    The status should be success
    The line 1 of output should match pattern 'Process counter (*) stopped.'
    The line 2 of output should match pattern 'Started counter (*)'
    The lines of output should eq 2
    The value "$(status_of idle)" should eq 'Exited (143)'
  End

  It 'rejects an unknown process name'
    When call bpm restart nosuch
    The status should be failure
    The output should eq 'Unknown process name: nosuch'
  End
End

Describe 'bpm restart of a process started with -t'
  BeforeEach 'setup_workdir' 'start_server -t counter'
  AfterEach 'cleanup_workdir'

  first_log_line () { sed -n '1s/\x1b\[[0-9;]*m//gp' "$(log_dir)/counter.log"; }
  logged () { [[ $(first_log_line) ]]; }

  It 'keeps the timestamps'
    restart_and_read_log () { bpm restart counter > /dev/null && wait_until 3 logged && first_log_line; }
    When call restart_and_read_log
    The output should match pattern '[0-2][0-9]:[0-5][0-9]:[0-5][0-9] counter *| tick'
  End
End
