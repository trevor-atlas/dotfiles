#!/bin/bash

if [ ! -d ".git" ]; then
  echo "Error: Not a git repository (no .git directory found)" >&2
  exit 1
fi

result=()

for dir in */; do
  dir_name="${dir%/}"
  if [ -f "$dir_name/tsconfig.json" ] && [ -d "$dir_name/static" ]; then
    result+=("\"$dir_name\"")
  fi
done

if [ ${#result[@]} -eq 0 ]; then
  echo "[]"
else
  printf '[%s]\n' "$(IFS=,; echo "${result[*]}")"
fi
