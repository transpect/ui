#!/usr/bin/env bash

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <program> <arg1> [arg2 ...] <output_file>"
  exit 1
fi

program="$1"
outfile="${@: -1}"          # last parameter = output file
args=("${@:2:$#-2}")        # all middle parameters = args

# run program with proper argument handling
"$program" "${args[@]}" > "$outfile" 2>&1
