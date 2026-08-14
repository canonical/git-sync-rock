set allow-duplicate-recipes
set allow-duplicate-variables
import? 'rocks.just'

source_repo := 'kubernetes/git-sync'

[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Patch all existing major.minor folders, then sync the embedded version.VERSION ldflag
[group("maintenance")]
update:
  #!/usr/bin/env bash
  set -e
  just --justfile rocks.just update
  # Re-apply the embedded version reference for every maintained major.minor folder
  for folder in $(find . -maxdepth 1 -type d -regextype posix-extended -regex '\./[0-9]+\.[0-9]+' -printf '%f\n'); do
    version="$(yq -r '.version' "$folder/rockcraft.yaml")"
    sed -i "s|version.VERSION=[^']*|version.VERSION=${version}|g" "$folder/rockcraft.yaml"
  done
