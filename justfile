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
  [[ -z "{{source_repo}}" ]] && { echo "× Set 'source_repo' in the local justfile"; exit 1; }
  for folder in $(find . -maxdepth 1 -type d -regextype posix-extended -regex '\./[0-9]+\.[0-9]+' -printf '%f\n' | sort -V); do
    read -r version tag < <(just resolve-tag "$folder")
    if [[ -z "$version" ]]; then echo "→ no upstream patch found for $folder, skipping"; continue; fi
    current="$(yq -r '.version' "$folder/rockcraft.yaml")"
    if [[ "$current" == "$version" ]]; then echo "→ $folder already at $version"; continue; fi
    echo "Updating $folder: $current → $version (source-tag $tag)"
    just write-version "$folder" "$version" "$tag"
    just sync-extra "$folder"
  done

# Onboard a new major.minor line (mirrors the blueprint, plus the non-standard fields)
[group("maintenance")]
add-version version:
  #!/usr/bin/env bash
  set -e
  [[ -z "{{source_repo}}" ]] && { echo "× Set 'source_repo' in the local justfile"; exit 1; }
  requested="{{version}}"; requested="${requested#v}"
  major_minor="$(echo "$requested" | grep -oP '^\d+\.\d+')"
  [[ -z "$major_minor" ]] && { echo "× could not parse a major.minor from '{{version}}'"; exit 1; }
  [[ -d "$major_minor" ]] && { echo "→ $major_minor/ already exists, nothing to do"; exit 0; }
  read -r version tag < <(just resolve-tag "$major_minor")
  [[ -z "$version" ]] && { echo "× no upstream release found for {{source_repo}} on the $major_minor line"; exit 1; }
  template="{{latest_version}}"
  [[ -z "$template" ]] && { echo "× no existing X.Y folder to copy from"; exit 1; }
  echo "Seeding $major_minor/ from $template/ ..."
  cp -r "$template" "$major_minor"
  just write-version "$major_minor" "$version" "$tag"
  just sync-extra "$major_minor"
  echo "✓ Created $major_minor/ at $version (source-tag $tag)"

# Re-apply the embedded version.VERSION ldflag for a single major.minor folder
[private]
sync-extra folder:
  #!/usr/bin/env bash
  set -e
  version="$(yq -r '.version' "{{folder}}/rockcraft.yaml")"
  sed -i "s|version.VERSION=[^']*|version.VERSION=${version}|g" "{{folder}}/rockcraft.yaml"
