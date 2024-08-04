#!/bin/bash

set -x
set -euo pipefail

converted=()
while IFS="" read -r f || [ -n "$f" ] ; do
  if [[ "$f" == *.wav ]] ; then
    echo "converting $f to FLAC"
    cf=$(dirname "$f")/$(basename "$f" .wav).flac
    ffmpeg -y -i "${f}" "$cf"
    converted+=("$cf")
  else
    converted+=("$f")
  fi
done < <(python ./cluster.py "${@}")

exec ./transcribe.sh "${converted[@]}"
