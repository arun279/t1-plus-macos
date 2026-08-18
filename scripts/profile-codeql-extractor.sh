#!/bin/bash

set -euo pipefail

if (($# == 0)); then
  printf 'Expected the extractor command and arguments.\n' >&2
  exit 64
fi

profile=false
for argument in "$@"; do
  case "$argument" in
    *Package.swift* | *T1PlusHelper*)
      profile=true
      break
      ;;
  esac
done

if [[ $profile == false ]]; then
  exec "$@"
fi

"$@" &
extractor_pid=$!

find_extractor_process() {
  local candidate child command cursor=0
  local -a pending=("$extractor_pid")

  while ((cursor < ${#pending[@]})); do
    candidate=${pending[$cursor]}
    ((cursor += 1))

    command=$(/bin/ps -p "$candidate" -o comm= 2> /dev/null || true)
    command=${command#"${command%%[![:space:]]*}"}
    command=${command%"${command##*[![:space:]]}"}
    if [[ ${command##*/} == extractor.real ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi

    while IFS= read -r child; do
      if [[ $child =~ ^[0-9]+$ ]]; then
        pending+=("$child")
      fi
    done < <(/usr/bin/pgrep -P "$candidate" 2> /dev/null || true)
  done

  return 1
}

profile_pid=
for ((attempt = 0; attempt < 100; attempt += 1)); do
  if profile_pid=$(find_extractor_process); then
    break
  fi
  if ! kill -0 "$extractor_pid" 2> /dev/null; then
    break
  fi
  /bin/sleep 0.1
done

profile_path="${RUNNER_TEMP:?}/codeql-extractor-sample-${extractor_pid}.txt"

if [[ -z $profile_pid ]]; then
  set +e
  wait "$extractor_pid"
  extractor_status=$?
  set -e

  {
    printf 'extractor.real was not observed within the selected process tree.\n'
    printf 'Wrapper PID: %d\n' "$extractor_pid"
  } > "$profile_path"

  if ((extractor_status != 0)); then
    exit "$extractor_status"
  fi
  exit 70
fi

printf 'Sampling extractor.real PID %d (wrapper PID %d).\n' "$profile_pid" "$extractor_pid"

set +e
/usr/bin/sample "$profile_pid" 60 5 -mayDie -fullPaths -file "$profile_path"
profile_status=$?
wait "$extractor_pid"
extractor_status=$?
set -e

if ((extractor_status != 0)); then
  exit "$extractor_status"
fi
if ((profile_status != 0)); then
  printf 'sample failed with status %d.\n' "$profile_status" >&2
  exit "$profile_status"
fi
