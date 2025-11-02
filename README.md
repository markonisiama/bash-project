# bash-project — logscan.sh

Lightweight Bash tool to analyze plain-text logs quickly: count errors, extract top IPv4s, or grep by regex.

---

## About

`logscan.sh` is a single Bash script that analyzes plaintext logs (e.g., `/var/log/*`, web/app logs) from files or STDIN. It has three modes:

- `--errors` — count lines containing `ERROR` or `CRITICAL`
- `--ips` — extract IPv4 addresses and show frequency (`-t N` for top N)
- `--grep REGEX` — filter by POSIX extended regular expressions (with `-i` ignore case, `-u` unique)

Uses only standard Unix tools; ideal for quick troubleshooting and coursework.

---

## Features

- Options and arguments with `-h` help output  
- Long options: `--errors`, `--ips`, `--grep`  
- Short options: `-f`, `-e`, `-t`, `-o`, `-i`, `-u`, `-h`  
- Regular expressions via `grep -E` and an IPv4 pattern  
- File I/O: read multiple files or STDIN; write to file with `-o`  
- Robust error handling (invalid flags, missing args/files, non-integer `-t`)  
- Output changes with flags (mode, top N, unique, case-insensitive)

---

## Quick Start

```bash
chmod +x logscan.sh
./logscan.sh -h
```

## Usage

```text
logscan.sh [-f FILE ...] [--errors | --ips | --grep REGEX] [-t N] [-o OUTFILE] [-i] [-u] [-h]

Core modes (choose one; default = --errors unless --grep/-e is provided):
  --errors            Count lines containing ERROR or CRITICAL.
  --ips               Extract IPv4 addresses and print frequency (use -t N for top N).
  --grep REGEX        Filter lines matching REGEX (POSIX ERE). Combine with -u for unique lines.

Inputs:
  -f FILE             One or more input files. If omitted, reads from STDIN.

Modifiers:
  -e REGEX            Shorthand for --grep REGEX.
  -t N                Limit to top N results (applies to --ips).
  -o OUTFILE          Write output to OUTFILE (creates/overwrites).
  -i                  Case-insensitive matching (for --grep/--errors).
  -u                  Unique lines (applies to --grep).
  -h                  Show help and exit.
  ```

---

## Examples

```bash
# 1) Count ERROR/CRITICAL in syslog
sudo ./logscan.sh -f /var/log/syslog --errors

# 2) Top 10 IPs in an nginx access log
./logscan.sh -f /var/log/nginx/access.log --ips -t 10

# 3) Grep “timeout” case-insensitive, unique, save to file
./logscan.sh -f app.log --grep 'timeout' -i -u -o timeouts.txt

# 4) Read from STDIN (no -f)
cat app.log | ./logscan.sh --grep 'database.*failed' -i
```

---

## Notes

- IPv4 regex: `([0-9]{1,3}\.){3}[0-9]{1,3}` (fast/practical; may include private/broadcast ranges).  
- Requires standard Unix tools: `bash`, `grep`, `sort`, `uniq`, `head`, `cat`.  
- Reading some system logs may require `sudo`.


---

## Contact

**Author:** Marko Nisiama  
**Email:** nisiamma@mail.uc.edu

