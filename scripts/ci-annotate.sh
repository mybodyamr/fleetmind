#!/usr/bin/env bash
# Runs a command; if it fails, republishes its output as a GitHub Actions error
# annotation. Annotations are readable through the checks API even when the raw
# job logs are not (this is how failing pgTAP output gets back to the author).
# Usage: scripts/ci-annotate.sh <title> <command...>
set -u
title="$1"; shift
out="$(mktemp)"
"$@" 2>&1 | tee "$out"
code=${PIPESTATUS[0]}
if [ "$code" -ne 0 ]; then
  msg="$(tail -c 20000 "$out" | perl -pe 's/%/%25/g; s/\r/%0D/g; s/\n/%0A/g')"
  echo "::error title=${title} failed (exit ${code})::${msg}"
fi
exit "$code"
