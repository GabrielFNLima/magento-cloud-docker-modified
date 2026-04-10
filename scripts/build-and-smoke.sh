#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES_DIR="$ROOT_DIR/images/php-nodejs"
DOCKER_REPO="devgfnl/magento-cloud-docker-php-node"
CLOUD_VERSION=""
PHP_FILTER=""
NODE_FILTER=""
CHANGED_ONLY=0
DIFF_BASE=""
DIFF_HEAD=""
VALIDATE_BASE=1

usage() {
  cat <<USAGE
Build and smoke-test Magento Cloud Docker PHP+Node images.

Usage:
  $(basename "$0") [options]

Options:
  --cloud-version <x.y.z>  Magento Cloud Docker version (ex: 1.4.7).
                           If omitted, auto-detects latest available (non changed-only mode).
  --php <value>            Filter PHP version(s), comma-separated.
                           Examples: 8.4 or 8.4-fpm or 8.3,8.4
  --node <value>           Filter node variant(s), comma-separated.
                           Examples: nodelts or node20,node24
  --repo <name>            Docker repository prefix.
                           Default: devgfnl/magento-cloud-docker-php-node
  --changed-only           Test only Dockerfiles changed in git diff.
  --diff-base <sha>        Base sha/ref used with --changed-only.
  --diff-head <sha>        Head sha/ref used with --changed-only.
  --no-validate-base       Skip validation of base image existence on Docker Hub.
  -h, --help               Show this help.

Examples:
  $(basename "$0")
  $(basename "$0") --cloud-version 1.4.7
  $(basename "$0") --php 8.4 --node nodelts
  $(basename "$0") --php 8.2,8.3 --node node20,node24 --cloud-version 1.4.7
  $(basename "$0") --changed-only --diff-base origin/main --diff-head HEAD
USAGE
}

normalize_php_token() {
  local token="$1"
  if [[ "$token" == *-fpm ]]; then
    printf '%s\n' "$token"
  else
    printf '%s-fpm\n' "$token"
  fi
}

csv_contains() {
  local csv="$1"
  local value="$2"
  if [[ -z "$csv" ]]; then
    return 0
  fi

  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    [[ "$item" == "$value" ]] && return 0
  done
  return 1
}

detect_latest_cloud_version() {
  find "$IMAGES_DIR" -mindepth 2 -maxdepth 2 -type d -printf '%f\n' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -n 1
}

extract_base_image() {
  local dockerfile="$1"
  awk '/^FROM[[:space:]]+/ {print $2; exit}' "$dockerfile"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cloud-version)
      CLOUD_VERSION="${2:-}"
      shift 2
      ;;
    --php)
      PHP_FILTER_RAW="${2:-}"
      PHP_FILTER=""
      IFS=',' read -r -a php_items <<< "$PHP_FILTER_RAW"
      for raw in "${php_items[@]}"; do
        norm="$(normalize_php_token "$raw")"
        if [[ -z "$PHP_FILTER" ]]; then
          PHP_FILTER="$norm"
        else
          PHP_FILTER+=",$norm"
        fi
      done
      shift 2
      ;;
    --node)
      NODE_FILTER="${2:-}"
      shift 2
      ;;
    --repo)
      DOCKER_REPO="${2:-}"
      shift 2
      ;;
    --changed-only)
      CHANGED_ONLY=1
      shift
      ;;
    --diff-base)
      DIFF_BASE="${2:-}"
      shift 2
      ;;
    --diff-head)
      DIFF_HEAD="${2:-}"
      shift 2
      ;;
    --no-validate-base)
      VALIDATE_BASE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$DIFF_BASE" || -n "$DIFF_HEAD" ]]; then
  if [[ $CHANGED_ONLY -ne 1 ]]; then
    echo "--diff-base/--diff-head require --changed-only" >&2
    exit 1
  fi
  if [[ -z "$DIFF_BASE" || -z "$DIFF_HEAD" ]]; then
    echo "Both --diff-base and --diff-head must be provided together" >&2
    exit 1
  fi
fi

if [[ $CHANGED_ONLY -eq 0 && -z "$CLOUD_VERSION" ]]; then
  CLOUD_VERSION="$(detect_latest_cloud_version)"
  if [[ -z "$CLOUD_VERSION" ]]; then
    echo "Could not detect a cloud version under $IMAGES_DIR" >&2
    exit 1
  fi
fi

if [[ $CHANGED_ONLY -eq 1 ]]; then
  echo "Mode: changed-only"
  if [[ -n "$DIFF_BASE" ]]; then
    echo "Diff range: $DIFF_BASE...$DIFF_HEAD"
  fi
else
  echo "Using cloud version: $CLOUD_VERSION"
fi
[[ $VALIDATE_BASE -eq 1 ]] && echo "Base image validation enabled (docker manifest inspect)."

built=0
skipped=0
failed=0
processed=0
failed_images=()

declare -A base_check_cache

run_target() {
  local php_version="$1"
  local cloud_version="$2"
  local node_variant="$3"
  local node_path="$4"
  local dockerfile="$node_path/Dockerfile"

  if ! csv_contains "$PHP_FILTER" "$php_version"; then
    skipped=$((skipped + 1))
    return
  fi

  if [[ -n "$CLOUD_VERSION" && "$cloud_version" != "$CLOUD_VERSION" ]]; then
    skipped=$((skipped + 1))
    return
  fi

  if ! csv_contains "$NODE_FILTER" "$node_variant"; then
    skipped=$((skipped + 1))
    return
  fi

  if [[ ! -f "$dockerfile" ]]; then
    skipped=$((skipped + 1))
    return
  fi

  local tag="${php_version}-${node_variant}-${cloud_version}"
  local image="${DOCKER_REPO}:${tag}"
  local base_image=""

  processed=$((processed + 1))
  echo ""
  base_image="$(extract_base_image "$dockerfile")"
  if [[ -z "$base_image" ]]; then
    echo "Could not determine base image from $dockerfile" >&2
    failed=$((failed + 1))
    failed_images+=("$image (missing FROM)")
    return
  fi

  if [[ $VALIDATE_BASE -eq 1 ]]; then
    if [[ -v "base_check_cache[$base_image]" ]]; then
      if [[ "${base_check_cache[$base_image]}" != "ok" ]]; then
        echo "Base image unavailable (cached): $base_image" >&2
        failed=$((failed + 1))
        failed_images+=("$image (missing base: $base_image)")
        return
      fi
    else
      echo "    Validating base image exists: $base_image"
      if docker manifest inspect "$base_image" >/dev/null 2>&1; then
        base_check_cache[$base_image]="ok"
      else
        base_check_cache[$base_image]="missing"
        echo "Base image unavailable on registry: $base_image" >&2
        failed=$((failed + 1))
        failed_images+=("$image (missing base: $base_image)")
        return
      fi
    fi
  fi

  echo "==> Building $image"
  if ! docker build -t "$image" "$node_path"; then
    echo "Build failed: $image" >&2
    failed=$((failed + 1))
    failed_images+=("$image (build)")
    return
  fi

  echo "==> Smoke test $image"
  if ! docker run --rm "$image" sh -lc 'php -v && node -v && yarn -v'; then
    echo "Smoke test failed: $image" >&2
    failed=$((failed + 1))
    failed_images+=("$image (smoke)")
    return
  fi

  built=$((built + 1))
}

if [[ $CHANGED_ONLY -eq 1 ]]; then
  diff_range=""
  if [[ -n "$DIFF_BASE" ]]; then
    diff_range="$DIFF_BASE...$DIFF_HEAD"
  else
    diff_range="HEAD~1...HEAD"
  fi

  mapfile -t changed_targets < <(
    git diff --name-only "$diff_range" -- 'images/php-nodejs/*/*/*/Dockerfile' \
      | awk -F/ 'NF>=6 {print $3 "|" $4 "|" $5}' \
      | sort -u
  )

  if [[ ${#changed_targets[@]} -eq 0 ]]; then
    echo "No changed Dockerfiles under images/php-nodejs in $diff_range."
    echo "Done. Built and tested: 0 | Failed: 0 | Skipped (by filters/missing dirs): 0"
    exit 0
  fi

  for key in "${changed_targets[@]}"; do
    IFS='|' read -r php_version cloud_version node_variant <<< "$key"
    node_path="$IMAGES_DIR/$php_version/$cloud_version/$node_variant"
    run_target "$php_version" "$cloud_version" "$node_variant" "$node_path"
  done
else
  for php_path in "$IMAGES_DIR"/*-fpm; do
    php_version="$(basename "$php_path")"
    version_dir="$php_path/$CLOUD_VERSION"

    if [[ ! -d "$version_dir" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    for node_path in "$version_dir"/*; do
      [[ -d "$node_path" ]] || continue
      node_variant="$(basename "$node_path")"
      run_target "$php_version" "$CLOUD_VERSION" "$node_variant" "$node_path"
    done
  done
fi

if [[ $processed -eq 0 && $failed -eq 0 ]]; then
  echo "No matching images found with current filters." >&2
  echo "Done. Built and tested: 0 | Failed: 0 | Skipped (by filters/missing dirs): $skipped"
  exit 1
fi

echo ""
echo "Done. Built and tested: $built | Failed: $failed | Skipped (by filters/missing dirs): $skipped"

if [[ ${#failed_images[@]} -gt 0 ]]; then
  echo "Failed images:"
  for item in "${failed_images[@]}"; do
    echo " - $item"
  done
fi

if [[ $failed -gt 0 ]]; then
  exit 1
fi
