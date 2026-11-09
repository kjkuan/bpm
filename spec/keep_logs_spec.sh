# shellcheck shell=bash

Describe 'logs kept in BPM_LOG_DIR'
  BeforeEach 'setup_workdir'
  AfterEach 'cleanup_workdir'

  talker_done () { has_exited talker; }
  talker_runs () { grep -c 'to stdout' "$WORK/logs/talker.log"; }

  It 'go there, and stay after the server exits'
    run_and_quit () {
      BPM_LOG_DIR=$WORK/logs start_server talker && wait_until 3 talker_done && stop_server
    }
    When call run_and_quit
    The status should be success
    The value "$(log_dir)" should eq "$WORK/logs"
    The value "$(talker_runs)" should eq 1
  End

  It 'can be given relative to where bpm is started'
    start_relative () { BPM_LOG_DIR=logs start_server talker && log_dir; }
    When call start_relative
    The output should eq "$WORK/logs"
  End

  It 'are appended to when a process restarts'
    restart_talker () {
      BPM_LOG_DIR=$WORK/logs start_server talker && wait_until 3 talker_done &&
        bpm restart talker > /dev/null && wait_until 3 talker_done
    }
    When call restart_talker
    The status should be success
    The value "$(talker_runs)" should eq 2
  End

  It 'are appended to by the next server'
    run_twice () {
      BPM_LOG_DIR=$WORK/logs start_server talker && wait_until 3 talker_done && stop_server &&
        BPM_LOG_DIR=$WORK/logs start_server talker && wait_until 3 talker_done
    }
    When call run_twice
    The status should be success
    The value "$(talker_runs)" should eq 2
  End
End
