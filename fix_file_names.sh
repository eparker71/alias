#!/usr/bin/env bash

# Set to 1 for preview (no changes), 0 to actually rename
DRY_RUN=1

fix_name() {
  local path="$1"

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  # Step 1: remove illegal characters
  new="$(echo "$base" | sed 's/[<>:"?*|\\]/_/g')"

  # Step 2: trim leading/trailing spaces
  new="$(echo "$new" | sed 's/^ *//; s/ *$//')"

  # Step 3: remove trailing periods
  new="$(echo "$new" | sed 's/\.*$//')"

  # If nothing changed, skip
  if [[ "$base" == "$new" ]]; then
    return
  fi

  target="$dir/$new"

  # Step 4: avoid overwrite
  if [[ -e "$target" ]]; then
    i=1
    while [[ -e "$dir/${new}_$i" ]]; do
      ((i++))
    done
    target="$dir/${new}_$i"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "mv \"$path\" \"$target\""
  else
    mv "$path" "$target"
  fi
}

export -f fix_name

# Process files and directories (bottom-up so renaming dirs doesn't break traversal)
find . -depth -print0 | while IFS= read -r -d '' file; do
  fix_name "$file"
done
