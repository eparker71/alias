#!/usr/bin/env bash

# Set to 1 for preview (no changes), 0 to actually rename
DRY_RUN=0

fix_name() {
  local path="$1"
  local dir base new target i

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  # Step 1: remove illegal characters
  new="$(echo "$base" | sed 's/[<>:"?*|\\]/_/g')"

  # Step 2: trim leading/trailing spaces
  new="$(echo "$new" | sed 's/^ *//; s/ *$//')"

  # Step 3: remove trailing periods
  new="$(echo "$new" | sed -E 's/\.+$//')"

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
    echo "[DRY RUN] would rename: \"$path\" -> \"$target\""
  else
    echo "[FIX] \"$path\" -> \"$target\""
    mv "$path" "$target"
  fi
  ((fixed++))
}

# Process files and directories (bottom-up so renaming dirs doesn't break traversal)
echo "Scanning for files to fix..."
count=0
fixed=0
while IFS= read -r -d '' file; do
  ((count++))
  if (( count % 100 == 0 )); then
    echo "  ... checked $count items so far (fixed $fixed)"
  fi
  fix_name "$file"
done < <(find . -mindepth 1 -depth -print0)
echo "Done. Checked $count items, fixed $fixed."
