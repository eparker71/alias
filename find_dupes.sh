#!/usr/bin/env bash
#
# find_dupes.sh — find duplicate files by content hash
#
# Usage: find_dupes.sh [directory] [-d] [-n]
#   directory  Directory to scan (default: current directory)
#   -d         Delete duplicates (keeps the file with the shortest path,
#              ties broken alphabetically; removes the rest)
#   -n         Dry run — show what would be deleted without doing it
#
# Files are compared by MD5 hash after grouping by size. Empty files are skipped.

SEARCH_DIR="."
DELETE=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    -d) DELETE=1 ;;
    -n) DRY_RUN=1 ;;
    -h|--help)
      sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) echo "Unknown option: $arg"; exit 1 ;;
    *)  SEARCH_DIR="$arg" ;;
  esac
done

if [[ ! -d "$SEARCH_DIR" ]]; then
  echo "Error: '$SEARCH_DIR' is not a directory."
  exit 1
fi

# Pick md5 command (macOS: md5, Linux: md5sum). Stderr suppressed so that
# cloud-storage timeout errors don't bleed through; failures are caught below.
if command -v md5sum &>/dev/null; then
  md5_of() { md5sum "$1" 2>/dev/null | cut -d' ' -f1; }
elif command -v md5 &>/dev/null; then
  md5_of() { md5 -q "$1" 2>/dev/null; }
else
  echo "Error: no md5 or md5sum command found."
  exit 1
fi

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

SIZE_LIST="$TMPDIR_WORK/sizes.txt"
HASH_LIST="$TMPDIR_WORK/hashes.txt"

# --- phase 1: collect file sizes ---
echo "Scanning '$SEARCH_DIR' ..."
file_count=0

while IFS= read -r -d '' f; do
  size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
  [[ -z "$size" || "$size" -eq 0 ]] && continue
  printf '%s\t%s\n' "$size" "$f" >> "$SIZE_LIST"
  ((file_count++))
  if (( file_count % 500 == 0 )); then
    echo "  ... scanned $file_count files"
  fi
done < <(find "$SEARCH_DIR" -type f -print0)

echo "  scanned $file_count files total."

if [[ ! -s "$SIZE_LIST" ]]; then
  echo "No files found."
  exit 0
fi

# --- phase 2: hash only files that share a size ---
# Find sizes that appear more than once
sort -t$'\t' -k1,1 "$SIZE_LIST" | awk -F'\t' '
  { sizes[$1] = sizes[$1] "\n" $2; counts[$1]++ }
  END { for (s in sizes) if (counts[s] > 1) print sizes[s] }
' | grep -v '^$' > "$TMPDIR_WORK/candidates.txt"

candidate_count=$(wc -l < "$TMPDIR_WORK/candidates.txt" | tr -d ' ')
echo "  $candidate_count candidate files to hash (share a size with another file)."

if [[ "$candidate_count" -eq 0 ]]; then
  echo ""
  echo "Done. No duplicate files found."
  exit 0
fi

skipped=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  h=$(md5_of "$f")
  if [[ -z "$h" ]]; then
    echo "  [SKIP] could not read (offline/unavailable?): $f"
    ((skipped++))
    continue
  fi
  printf '%s\t%s\n' "$h" "$f" >> "$HASH_LIST"
done < "$TMPDIR_WORK/candidates.txt"

# --- phase 3: find hashes that appear more than once ---
sort -t$'\t' -k1,1 "$HASH_LIST" > "$TMPDIR_WORK/hashes_sorted.txt"

dupe_groups=0
dupe_files=0
deleted=0
current_hash=""
current_group=()

process_group() {
  local grp=("$@")
  (( ${#grp[@]} < 2 )) && return

  ((dupe_groups++))

  # Sort by path length (shortest first), then alphabetically — pick keeper
  IFS=$'\n' sorted=($(printf '%s\n' "${grp[@]}" | awk '{ print length, $0 }' | sort -n -k1,1 -k2,2 | cut -d' ' -f2-))
  unset IFS
  local keeper="${sorted[0]}"

  echo ""
  echo "[DUPLICATE GROUP] hash=$current_hash"
  echo "  keep: $keeper"

  local i
  for (( i=1; i<${#sorted[@]}; i++ )); do
    local f="${sorted[$i]}"
    ((dupe_files++))
    if [[ $DELETE -eq 1 ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        echo "  [DRY RUN] would delete: $f"
      else
        echo "  [DELETE] $f"
        rm -- "$f"
        ((deleted++))
      fi
    else
      echo "  dupe: $f"
    fi
  done
}

while IFS=$'\t' read -r h f; do
  if [[ "$h" != "$current_hash" ]]; then
    if [[ -n "$current_hash" ]]; then
      process_group "${current_group[@]}"
    fi
    current_hash="$h"
    current_group=("$f")
  else
    current_group+=("$f")
  fi
done < "$TMPDIR_WORK/hashes_sorted.txt"
# flush last group
if [[ -n "$current_hash" ]]; then
  process_group "${current_group[@]}"
fi

echo ""
echo "Done. Found $dupe_groups duplicate group(s) with $dupe_files extra file(s)."
if [[ $DELETE -eq 1 && $DRY_RUN -eq 0 ]]; then
  echo "Deleted $deleted file(s)."
fi
if [[ $skipped -gt 0 ]]; then
  echo "Skipped $skipped file(s) that could not be read (likely not downloaded from cloud storage)."
fi
