# shellcheck shell=bash

Describe 'bpm without a server'
  BeforeEach 'setup_workdir'
  AfterEach 'cleanup_workdir'

  It 'shows the usage with -h'
    When call bpm -h
    The status should be success
    The output should include 'Usage: bpm'
  End

  It 'lists the defined processes'
    When call bpm list
    The status should be success
    The output should eq "$(printf '%s\n' counter fails family idle selfkill selfterm)"
  End

  It 'refuses other commands'
    When call bpm stop
    The status should be failure
    The stderr should eq 'No process has been started by BPM. Please start one first.'
  End

  It 'accepts -f with a bare filename'
    mv "$WORK/Procfile.sh" "$WORK/procs.sh"
    When call bpm -f procs.sh list
    The status should be success
    The line 1 of output should eq counter
  End

  It 'rejects -f with a nonexistent directory'
    When call bpm -f nope/procs.sh list
    The status should be failure
    The stderr should include 'Invalid Procfile path: nope/procs.sh'
  End

  It 'fails on a Procfile with an invalid process name'
    echo 'Proc/bad* () { :; }' >> "$WORK/Procfile.sh"
    When call bpm list
    The status should be failure
    The output should eq ''
    The stderr should include 'Invalid process name: Proc/bad*'
  End

  Describe 'with a stale command FIFO'
    dead_pid () { sh -c 'echo $$'; }

    setup_stale () {
      mkfifo "$WORK/.bpmfifo"
      dead_pid > "$WORK/.bpmpid"
    }
    BeforeEach 'setup_stale'

    It 'removes it instead of blocking the client'
      When call bpm list
      The status should be success
      The line 1 of output should eq counter
      The stderr should include 'Removing stale'
      The path "$WORK/.bpmfifo" should not be exist
      The path "$WORK/.bpmpid" should not be exist
    End

    It 'can still start a new server'
      start_with_stale () { start_server idle; }
      When call start_with_stale
      The status should be success
      The value "$(server_pid)" should be present
    End
  End
End
