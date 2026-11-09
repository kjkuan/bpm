# shellcheck shell=bash

Describe 'bpm quit'
  BeforeEach 'setup_workdir' 'start_server counter idle'
  AfterEach 'cleanup_workdir'

  It 'stops all processes and the server, replying to the client'
    server=
    quit () { server=$(server_pid) && bpm quit; }
    When call quit
    The status should be success
    The line 1 of output should match pattern 'Process counter (*) stopped.'
    The line 2 of output should match pattern 'Process idle (*) stopped.'
    The lines of output should eq 2
    The value "$(wait_until 5 server_gone "$server" && echo gone)" should eq gone
    The value "$(cat "$WORK/counter.exit" 2>/dev/null)" should eq done
    The path "$WORK/.bpmfifo" should not be exist
    The path "$WORK/.bpmpid" should not be exist
  End
End
