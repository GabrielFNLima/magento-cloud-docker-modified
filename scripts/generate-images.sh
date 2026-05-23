#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES_DIR="$ROOT_DIR/images/php-nodejs"
NODE_VARIANTS=("node20" "node24" "nodelts")
MIN_CLOUD_VERSION="${MIN_CLOUD_VERSION:-1.4.7}"
DRY_RUN=0

usage() {
  cat <<USAGE
Query Docker Hub for magento/magento-cloud-docker-php tags and generate
missing Dockerfiles under images/php-nodejs/.

Usage:
  $(basename "$0") [options]

Options:
  --min-cloud-version <x.y.z>  Minimum cloud version to consider (default: 1.4.7).
  --dry-run                    Print what would be created without writing files.
  -h, --help                   Show this help.

Examples:
  $(basename "$0")
  $(basename "$0") --dry-run
  $(basename "$0") --min-cloud-version 1.4.8
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-cloud-version) MIN_CLOUD_VERSION="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

version_gte() {
  # Returns 0 (true) if $1 >= $2 using sort -V
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

node_setup_script() {
  case "$1" in
    node20)  echo "setup_20.x" ;;
    node24)  echo "setup_24.x" ;;
    nodelts) echo "setup_lts.x" ;;
    *)       echo "" ;;
  esac
}

node_comment() {
  case "$1" in
    node20)  echo "Node.js 20.x" ;;
    node24)  echo "Node.js 24.x" ;;
    nodelts) echo "Node.js LTS" ;;
    *)       echo "Node.js" ;;
  esac
}

generate_dockerfile() {
  local php_version="$1"   # e.g. 8.4-fpm
  local cloud_version="$2" # e.g. 1.4.8
  local node_variant="$3"  # e.g. node24

  local setup_script
  setup_script="$(node_setup_script "$node_variant")"
  local comment
  comment="$(node_comment "$node_variant")"

  cat <<DOCKERFILE
FROM magento/magento-cloud-docker-php:${php_version}-${cloud_version}

# Install ${comment}
RUN curl -sL https://deb.nodesource.com/${setup_script} | bash - && \\
  apt-get install -y nodejs && \\
  apt-get clean && \\
  rm -rf /var/lib/apt/lists/*


# Install Yarn
RUN npm install -g yarn

CMD ["php-fpm", "-R"]
DOCKERFILE
}

echo "Fetching tags from Docker Hub for magento/magento-cloud-docker-php ..."

# Paginate through all tags (100 per page)
all_tags=()
page=1
while true; do
  response=$(curl -fsSL \
    "https://hub.docker.com/v2/repositories/magento/magento-cloud-docker-php/tags?page_size=100&page=${page}")

  tags=$(echo "$response" | grep -oE '"name":"[^"]+"' | sed 's/"name":"//;s/"//' || true)
  if [[ -z "$tags" ]]; then
    break
  fi

  mapfile -t page_tags <<< "$tags"
  all_tags+=("${page_tags[@]}")

  # Check if there's a next page
  has_next=$(echo "$response" | grep -oE '"next":"[^"]+"' | head -1 || true)
  [[ -z "$has_next" ]] && break
  page=$((page + 1))
done

echo "Total tags fetched: ${#all_tags[@]}"

# Parse tags matching pattern: {php}-fpm-{cloud_version}
# e.g. "8.4-fpm-1.4.8"
created=0
skipped=0

for tag in "${all_tags[@]}"; do
  if [[ ! "$tag" =~ ^([0-9]+\.[0-9]+)-fpm-([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    continue
  fi

  php_version="${BASH_REMATCH[1]}-fpm"
  cloud_version="${BASH_REMATCH[2]}"

  if ! version_gte "$cloud_version" "$MIN_CLOUD_VERSION"; then
    continue
  fi

  for node_variant in "${NODE_VARIANTS[@]}"; do
    target_dir="$IMAGES_DIR/$php_version/$cloud_version/$node_variant"
    dockerfile="$target_dir/Dockerfile"

    if [[ -f "$dockerfile" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    echo "NEW  $php_version / $cloud_version / $node_variant"

    if [[ $DRY_RUN -eq 1 ]]; then
      echo "     [dry-run] would create $dockerfile"
      created=$((created + 1))
      continue
    fi

    mkdir -p "$target_dir"
    generate_dockerfile "$php_version" "$cloud_version" "$node_variant" > "$dockerfile"
    echo "     Created $dockerfile"
    created=$((created + 1))
  done
done

echo ""
echo "Done. Created: $created | Already existed (skipped): $skipped"

if [[ $created -gt 0 && $DRY_RUN -eq 0 ]]; then
  echo ""
  echo "Run the smoke test to validate:"
  echo "  ./scripts/build-and-smoke.sh"
fi
