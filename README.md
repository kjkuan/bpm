## What is it?
**BPM** (Bash Process Manager) is a simple process runner / manager inspired by
[Foreman] and tools alike. It is built based on *Bash*'s job / process management
capability.

## Features
- `Procfile.sh` -- declare the processes to be run as a shell script.
- Processes defined in the `Procfile.sh` can be started / restarted / stopped individually.
- Logs process outputs to temporary files in addition to following the outputs, allowing third-party log viewing tools to be used for querying / filtering.
- Correctly kills the entire process group when stopping a process.
- Simple, single file implementation; runs wherever Bash is available.

[Foreman]: https://github.com/ddollar/foreman

## Examples
TBD ... show a simple `Profile.sh` with example usages 
