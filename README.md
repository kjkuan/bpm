## What is it?
**BPM** (Bash Process Manager) is a simple process runner / manager inspired by
[Foreman] and tools alike. It is built based on *Bash*'s job / process management
capability.

## Features
- `Procfile.sh` -- declare the processes to be run as functions in a Bash script.
- Processes defined in the `Procfile.sh` can be started / restarted / stopped individually.
- Logs process outputs to temporary files in addition to following the outputs, allowing third-party log viewing tools to be used for querying / filtering.
- Correctly kills the entire process group when stopping a process.
- Simple, single file implementation; runs wherever Bash 4.4 or newer is available.

[Foreman]: https://github.com/ddollar/foreman

## Examples

With the example [Procfile.sh](Procfile.sh) script, we can start the processes with:

    ./bpm start

Then, in another shell, we can check the process statuses, as well as, starting or stopping the processes:

    # Restart p1
    ./bpm list
    ./bpm stop p1
    ./bpm list
    ./bpm start p1

    # ... or in one go
    ./bpm restart p1

    # Stop p2
    ./bpm stop p2
    ./bpm list

    # Follow p1's log (with `tail -qF`, or whatever $BPM_LOG_VIEWER says),
    # or print the paths of all the log files
    ./bpm logs p1
    ./bpm logs -p

    # Stop all processes
    ./bpm stop

    # Stop all processes, and the BPM server
    ./bpm quit

Also, one can hit `Ctrl-C` in the log output window, where the first process was started,
to stop all processes and quit the **BPM** monitoring process. Closing that window, or
killing the **BPM** server process with `kill` (`TERM`), does the same.

Run `./bpm -h` for all the commands and options.

## Procfile.sh

A `Procfile.sh` is a Bash script that defines each process as a function named
`Proc/NAME`, where `NAME` is the process name used with `bpm start` / `bpm stop`.
By default, BPM uses `./Procfile.sh`; use `-f PATH` to use another one.

    Proc/web () { python3 -m http.server 8000; }
    Proc/worker () { ./worker.sh --verbose; }

Process names can't contain `*` or `?`; a `Procfile.sh` defining such a process
fails to load.

### How it's loaded

BPM sources `Procfile.sh` in a subshell, from the directory containing it, and keeps
**only the `Proc/*` function definitions** (and the directory it ended up in; see
below). Everything else it defines -- other functions, variables (exported or not),
aliases, shell options and traps -- is discarded, so that it can't interfere with
BPM itself.

Other top-level commands are still run, so a `Procfile.sh` can have side effects
when it's loaded, e.g., sourcing other files or printing messages. Note that:

- It's loaded every time `bpm` runs, including each `bpm list` / `bpm stop`, not
  just when the processes are started.

- Its standard output is discarded; print messages to standard error instead
  (`echo "..." >&2`).

### Writing a process

Each `Proc/NAME` function must be self-contained, since nothing else from
`Procfile.sh` is available when it runs. To share code between processes, define
it inside the function, or source it from there:

    Proc/api () {
        source ./common.sh   # relative to the process' working directory; see below
        start_api_server
    }

When a process runs:

- **Working directory**: it starts in the directory containing `Procfile.sh`, or,
  if `Procfile.sh` changed directory at the top level (e.g., `cd app`, relative to
  its own directory), in the directory it ended up in. The directory `bpm` was
  run from doesn't matter.

- **Environment**: it inherits the environment of the shell that ran `bpm start`.
  Of shell functions, only the `Proc/*` ones are defined, so it can call other
  processes' functions, but none of BPM's own.

- **Input / output**: its standard input is `/dev/null`. Its standard output and
  standard error both go to its log, with each line prefixed by its name (and a
  timestamp with `bpm start -t`). A last line without a trailing newline is kept.

- **Process group**: it runs in its own process group, which includes everything
  it starts. `bpm stop` signals the whole group, so its descendants are stopped
  too -- unless they move to a process group of their own (e.g., with `setsid`, or
  daemons that detach), which BPM can't track.

### Stopping a process

`bpm stop [-s SIGNAL] NAME` sends `SIGNAL` (`TERM` by default; `INT` and `KILL` are
also allowed) to the process' group. If the group is still running after
`BPM_STOP_TIMEOUT` seconds (5 by default, read when the server starts), BPM kills
it with `KILL`.

The BPM server stops all running processes the same way, and then exits, on
`Ctrl-C` (`INT`) in its window, when its window (terminal) is closed (`HUP`), or
on `TERM` (e.g., `kill SERVER_PID`). Only `KILL` stops the server without
stopping its processes, leaving them running.

On `TERM` or `INT`, a process' `EXIT` trap runs, so it can clean up there (as `p1`
in the example [Procfile.sh](Procfile.sh) does). Nothing runs on `KILL`.

`bpm list` shows each process' status, PID and start time:

    NAME  STATUS            PID     STARTED
    p1    running           647711  00:44:22, 6s ago
    p2    killed (SIGTERM)  647716  00:44:22
    p3    exited (1)        647724  00:44:22

A process is `running`, `not started`, `exited (N)` with the status it exited
with, or `killed (SIGNAL)` if it ended by a signal (an exit status over 128;
e.g., when stopped with `TERM`).

### Logs

Each process logs to `NAME.log` in a temporary directory, shown when the server
starts (`Logging to ...`), which is removed when the server exits. Restarting a
process starts its log afresh.

To keep the logs, e.g., to look into a crash afterwards, set `BPM_LOG_DIR` (see
below): the logs then go to that directory and stay there, and processes append
to them, across restarts and servers, instead of starting them afresh.

Each log line is prefixed with the process' name, in a color of its own if the
server's output is a terminal (and `NO_COLOR` isn't set). The colors are written
into the log files.

Use `bpm logs [NAME...]` to follow the logs (see `BPM_LOG_VIEWER` below), or
`bpm logs -p [NAME...]` to print the log files' paths, e.g., for other tools.

## Environment variables

- `BPM_STOP_TIMEOUT`: seconds to give a process to exit after the stop signal
  before killing it with `KILL` (default: 5). It's read by the server, once, when
  it starts, so set it for `bpm start`:

      BPM_STOP_TIMEOUT=10 ./bpm start

- `BPM_LOG_DIR`: a directory to write the logs to and keep them in, instead of a
  temporary directory removed on exit. It's created if needed, and a relative
  path is relative to where `bpm start` is run. Processes append to their logs in
  it. It's read by the server when it starts:

      BPM_LOG_DIR=logs ./bpm start

- `NO_COLOR`: if set (to anything), log lines aren't colored. They aren't either
  when the server's output isn't a terminal. See https://no-color.org.

- `BPM_LOG_VIEWER`: the command `bpm logs` follows the logs with, given the log
  files as arguments (default: `tail -qF`). It's read by `bpm logs` itself, so it
  can differ from one call to the next:

      BPM_LOG_VIEWER=lnav ./bpm logs web worker

  It's split into words on whitespace, and quotes in it aren't honored:
  `BPM_LOG_VIEWER='less +F'` works, but an argument containing spaces can't be
  given. For anything more involved, point it at a small wrapper script.
