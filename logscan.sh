#!/usr/bin/env bash
# logscan.sh — Lightweight log analyzer for plain-text logs (e.g., /var/log/*, app logs)

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_NAME="$(basename "$0")"

print_help() {
  cat <<'EOF'
Usage:
  logscan.sh [-f FILE ...] [--errors | --ips | --grep REGEX] [-t N] [-o OUTFILE] [-i] [-u] [-h]

Core modes (choose one; default is --errors unless --grep/-e is provided):
  --errors            Count lines containing ERROR or CRITICAL (case-insensitive with -i).
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
  -h                  Show this help message and exit.

Examples:
  sudo ./logscan.sh -f /var/log/syslog --errors
  ./logscan.sh -f access.log --ips -t 10
  ./logscan.sh -f app.log --grep 'timeout' -i -u -o timeouts.txt
EOF
}

# Defaults
declare -a FILES=()
MODE=""
REGEX=""
TOP_N=""
OUTFILE=""
CASE_INSENSITIVE=0
UNIQUE=0

LONG_ERRORS=0
LONG_IPS=0
LONG_GREP=0

# Pre-parse long options
declare -a ARGS=()
while (($#)); do
  case "$1" in
    --errors) LONG_ERRORS=1; shift; continue ;;
    --ips)    LONG_IPS=1; shift; continue ;;
    --grep)   LONG_GREP=1; shift; REGEX="${1:-}"; if [[ -z "${REGEX}" ]]; then
                echo "[$SCRIPT_NAME] error: --grep requires a REGEX" >&2; exit 2; fi; shift; continue ;;
    --help)   print_help; exit 0 ;;
    --*)      echo "[$SCRIPT_NAME] error: unknown option '$1'"; echo "Try '$SCRIPT_NAME -h'"; exit 2 ;;
    *)        ARGS+=("$1"); shift; continue ;;
  esac
done
set -- "${ARGS[@]}"

while getopts ":f:e:t:o:iuh" opt; do
  case "${opt}" in
    f) FILES+=("$OPTARG") ;;
    e) REGEX="$OPTARG"; LONG_GREP=1 ;;
    t) TOP_N="$OPTARG" ;;
    o) OUTFILE="$OPTARG" ;;
    i) CASE_INSENSITIVE=1 ;;
    u) UNIQUE=1 ;;
    h) print_help; exit 0 ;;
    :) echo "[$SCRIPT_NAME] error: option -$OPTARG requires an argument" >&2; exit 2 ;;
    \?) echo "[$SCRIPT_NAME] error: invalid option -$OPTARG" >&2; echo "Try '$SCRIPT_NAME -h'"; exit 2 ;;
  esac
done

# Resolve mode
if (( LONG_ERRORS + LONG_IPS + LONG_GREP > 1 )); then
  echo "[$SCRIPT_NAME] error: choose only one mode among --errors, --ips, --grep" >&2
  exit 2
fi
if (( LONG_ERRORS == 1 )); then MODE="errors"; fi
if (( LONG_IPS == 1 ));    then MODE="ips";    fi
if (( LONG_GREP == 1 ));   then MODE="grep";   fi
if [[ -z "$MODE" ]]; then MODE="errors"; fi

# Validate
if ((${#FILES[@]} > 0)); then
  for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
      echo "[$SCRIPT_NAME] error: file not found: $f" >&2
      exit 2
    fi
  done
fi
if [[ "$MODE" == "grep" && -z "$REGEX" ]]; then
  echo "[$SCRIPT_NAME] error: --grep requires a REGEX (use -e REGEX or --grep REGEX)" >&2
  exit 2
fi
if [[ -n "$TOP_N" && ! "$TOP_N" =~ ^[0-9]+$ ]]; then
  echo "[$SCRIPT_NAME] error: -t N expects an integer" >&2
  exit 2
fi

GREP_FLAGS="-E"
if (( CASE_INSENSITIVE )); then GREP_FLAGS="-Ei"; fi

build_input() {
  if ((${#FILES[@]} > 0)); then
    cat -- "${FILES[@]}"
  else
    if [ -t 0 ]; then
      echo "[$SCRIPT_NAME] reading from STDIN... (Ctrl+D to end)" >&2
    fi
    cat -
  fi
}

emit() {
  if [[ -n "$OUTFILE" ]]; then
    cat > "$OUTFILE"
    echo "[$SCRIPT_NAME] wrote results to: $OUTFILE" >&2
  else
    cat
  fi
}

run_errors() {
  local pattern="(ERROR|CRITICAL)"
  if (( CASE_INSENSITIVE )); then
    build_input | grep -Eio "$pattern" | tr '[:lower:]' '[:upper:]' | sort | uniq -c | sort -nr | emit
  else
    build_input | grep -Eo  "$pattern" | sort | uniq -c | sort -nr | emit
  fi
}

run_ips() {
  local ipre='([0-9]{1,3}\.){3}[0-9]{1,3}'
  local stream
  stream="$(build_input | grep -Eo "$ipre" | sort | uniq -c | sort -nr)"
  {
    echo "COUNT IP"
    if [[ -n "$TOP_N" ]]; then
      echo "$stream" | head -n "$TOP_N"
    else
      echo "$stream"
    fi
  } | emit
}

run_grep() {
  if (( UNIQUE )); then
    build_input | grep $GREP_FLAGS -- "$REGEX" | sort | uniq | emit
  else
    build_input | grep $GREP_FLAGS -- "$REGEX" | emit
  fi
}

case "$MODE" in
  errors) run_errors ;;
  ips)    run_ips    ;;
  grep)   run_grep   ;;
  *) echo "[$SCRIPT_NAME] internal error: unknown MODE '$MODE'" >&2; exit 1 ;;
esac
