#!/usr/bin/env bash
# Generic build / release script for FS mods.
# Automatically detects mod name from modDesc.xml and FS version from directory name.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_mod_name_from_descriptor() {
  local desc_path="$1"
  if [ ! -f "$desc_path" ]; then
    echo "ERROR: modDesc.xml not found: $desc_path" >&2
    exit 1
  fi

  # Extract first title element (English or first available)
  local title
  title=$(grep -oP '(?<=<title>)[^<]*(?=</title>)' "$desc_path" | head -1)

  if [ -z "$title" ]; then
    # Try to extract from <en> or <de> tags within <title>
    title=$(sed -n 's/.*<\(en\|de\)>\([^<]*\)<.*/\2/p' "$desc_path" | head -1)
  fi

  if [ -z "$title" ]; then
    echo "ERROR: Could not parse mod title from $desc_path" >&2
    exit 1
  fi

  # Convert to valid filename: remove spaces/special chars, keep alphanumeric and underscores
  echo "$title" | sed 's/[^a-zA-Z0-9_]//g'
}

detect_latest_fs_version() {
  local latest=""
  for d in "${SCRIPT_DIR}"/FS*_Src; do
    [ -d "$d" ] || continue
    local name
    name="$(basename "$d")"
    local ver="${name#FS}"
    ver="${ver%_Src}"
    if [ -z "$latest" ] || [ "$ver" -gt "$latest" ] 2>/dev/null; then
      latest="$ver"
    fi
  done

  if [ -z "$latest" ]; then
    echo "ERROR: No FS*_Src directories found in ${SCRIPT_DIR}" >&2
    exit 1
  fi
  echo "$latest"
}

parse_fs_versions() {
  local raw="$1"
  IFS=',' read -ra FS_VERSIONS <<< "$raw"
}

usage() {
  echo "Usage:"
  echo "  $0 build [--fs_ver VER]"
  echo "  $0 release-test [--fs_ver VER]"
  echo "  $0 release <semver> [--fs_ver VER]"
  echo ""
  echo "VER is a single version (25) or comma-separated list (25,28)."
  echo "Defaults to the latest FS*_Src directory if omitted."
  exit 1
}

do_build() {
  local fs_ver="$1"
  local src_dir="${SCRIPT_DIR}/FS${fs_ver}_Src"
  local mod_name
  mod_name=$(get_mod_name_from_descriptor "${src_dir}/modDesc.xml")
  local zip_name="FS${fs_ver}_${mod_name}"
  local out_dir="${SCRIPT_DIR}/dist"
  local zip_path="${out_dir}/${zip_name}.zip"

  if [ ! -d "$src_dir" ]; then
    echo "ERROR: Source directory not found: ${src_dir}" >&2
    exit 1
  fi

  echo "Building ${zip_name}.zip from FS${fs_ver}_Src ..."

  mkdir -p "$out_dir"
  rm -f "$zip_path"

  local staging
  staging="$(mktemp -d)"

  cp -r "$src_dir"/* "$staging/"

  # Remove dev files (backups, logs)
  find "$staging" -name '*.bak' -delete 2>/dev/null || true
  find "$staging" -name '*.log' -delete 2>/dev/null || true
  find "$staging" -name '*.png' -delete 2>/dev/null || true

  if command -v zip &>/dev/null; then
    (cd "$staging" && zip -rq "$zip_path" .)
  elif command -v git &>/dev/null; then
    (cd "$staging" && git init -q && git add -A && git commit -qm "build" && git archive --format=zip -o "$zip_path" HEAD)
    rm -rf "$staging/.git"
  else
    echo "ERROR: No zip tool found. Install 'zip' or 'git'." >&2
    rm -rf "$staging"
    exit 1
  fi

  rm -rf "$staging"

  local size
  size=$(du -k "$zip_path" | cut -f1)
  echo "  Created: ${zip_path} (${size} KB)"
  echo "Done."
}

do_release() {
  local version="$1"
  shift
  local fs_versions=("$@")

  local tag="release/${version}"

  if ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z]+\.[0-9]+)?$'; then
    echo "ERROR: Invalid version format '${version}'." >&2
    echo "  Expected: X.Y.Z.W  or  X.Y.Z.W-alpha.N  or  X.Y.Z.W-beta.N" >&2
    exit 1
  fi

  for fv in "${fs_versions[@]}"; do
    local src_dir="${SCRIPT_DIR}/FS${fv}_Src"
    if [ ! -d "$src_dir" ]; then
      echo "ERROR: Source directory not found: ${src_dir}" >&2
      exit 1
    fi
  done

  if [ -n "$(git -C "$SCRIPT_DIR" status --porcelain)" ]; then
    echo "ERROR: Working tree is not clean. Commit or stash changes first." >&2
    exit 1
  fi

  for fv in "${fs_versions[@]}"; do
    do_build "$fv"
  done

  local json_array
  json_array=$(printf '%s\n' "${fs_versions[@]}" | jq -s '.')
  echo "{\"versions\": ${json_array}}" > "${SCRIPT_DIR}/fs_versions.json"

  git -C "$SCRIPT_DIR" add fs_versions.json
  if ! git -C "$SCRIPT_DIR" diff --cached --quiet; then
    git -C "$SCRIPT_DIR" commit -m "Set build targets to FS$(IFS=,; echo "${fs_versions[*]}") for ${version}"
  fi

  echo ""
  local fs_list
  fs_list=$(IFS=', '; echo "${fs_versions[*]}")
  echo "Creating tag: ${tag} (FS versions: ${fs_list})"
  git -C "$SCRIPT_DIR" tag -a "$tag" -m "Release ${version} (FS${fs_list})"
  git -C "$SCRIPT_DIR" push origin HEAD "$tag"

  echo ""
  echo "Release tag '${tag}' pushed. CI will build and publish the GitHub release."
}

if [ $# -lt 1 ]; then
  usage
fi

COMMAND="$1"
shift

POSITIONAL=()
FS_VERSIONS=()
FS_VER_RAW=""

while [ $# -gt 0 ]; do
  case "$1" in
    --fs_ver)
      if [ $# -lt 2 ]; then
        echo "ERROR: --fs_ver requires a value (e.g. --fs_ver 25,28)" >&2
        exit 1
      fi
      FS_VER_RAW="$2"
      shift 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [ -n "$FS_VER_RAW" ]; then
  parse_fs_versions "$FS_VER_RAW"
else
  FS_VERSIONS=("$(detect_latest_fs_version)")
fi

case "$COMMAND" in
  build)
    do_build "${FS_VERSIONS[0]}"
    ;;
  release-test)
    do_build "${FS_VERSIONS[0]}"
    ;;
  release)
    if [ ${#POSITIONAL[@]} -lt 1 ]; then
      echo "ERROR: release requires a version argument." >&2
      usage
    fi
    do_release "${POSITIONAL[0]}" "${FS_VERSIONS[@]}"
    ;;
  *)
    echo "ERROR: Unknown command '${COMMAND}'" >&2
    usage
    ;;
esac
