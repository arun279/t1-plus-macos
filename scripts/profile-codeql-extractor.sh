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
profile_path="${RUNNER_TEMP:?}/codeql-extractor-sample-${extractor_pid}.txt"

set +e
/usr/bin/sample "$extractor_pid" 60 5 -mayDie -fullPaths -file "$profile_path"
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
