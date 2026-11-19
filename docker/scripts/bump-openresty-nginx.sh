#!/bin/bash -e

# Rebuild an OpenResty source tree on a newer upstream nginx core.
#
# Used when nginx ships security fixes before OpenResty publishes a release
# that bundles them. OpenResty's own nginx patches are re-applied to the new
# core; the build fails if any of them does not apply.
#
# Usage: bump-openresty-nginx.sh <openresty-source-dir> <nginx-version> <sha256>
#   <sha256> is the checksum of
#   https://github.com/nginx/nginx/archive/refs/tags/release-<nginx-version>.tar.gz

BLUE='\E[1;34m'
CYAN='\E[1;36m'
YELLOW='\E[1;33m'
GREEN='\E[1;32m'
RESET='\E[0m'

SRC_DIR="$1"
NEW="$2"
SHA256="$3"

if [ -z "$SRC_DIR" ] || [ -z "$NEW" ] || [ -z "$SHA256" ]; then
	echo "Usage: $0 <openresty-source-dir> <nginx-version> <sha256>" >&2
	exit 1
fi

cd "$SRC_DIR"

OLD="$(sed -n 's/^main_ver=//p' util/ver)"
if [ -z "$OLD" ] || [ ! -d "patches/nginx/${OLD}" ]; then
	echo "Cannot determine the bundled nginx version from util/ver" >&2
	exit 1
fi
if [ "$OLD" = "$NEW" ]; then
	echo -e "${BLUE}❯ ${CYAN}OpenResty already bundles nginx ${YELLOW}${NEW}${CYAN}, nothing to do${RESET}"
	exit 0
fi

echo -e "${BLUE}❯ ${CYAN}Rebasing OpenResty nginx core ${YELLOW}${OLD}${CYAN} -> ${YELLOW}${NEW}${CYAN}...${RESET}"

# OpenResty's nginx mirror is the upstream repository tree at the release tag,
# with auto/configure moved to the top level. Rebuild that from the tag and
# seed it into util/get-tarball's cache so it is used instead of a download.
TMP="$(mktemp -d)"
wget -q "https://github.com/nginx/nginx/archive/refs/tags/release-${NEW}.tar.gz" -O "${TMP}/src.tar.gz"
echo "${SHA256}  ${TMP}/src.tar.gz" | sha256sum -c -
tar -xzf "${TMP}/src.tar.gz" -C "$TMP"
mv "${TMP}/nginx-release-${NEW}" "${TMP}/nginx-${NEW}"
mv "${TMP}/nginx-${NEW}/auto/configure" "${TMP}/nginx-${NEW}/configure"
mkdir -p work
tar -czf "work/nginx-${NEW}.tar.gz" -C "$TMP" "nginx-${NEW}"
rm -rf "$TMP"

# Carry OpenResty's nginx patches over to the new version. Some patches embed
# the version string in their paths or context, so rewrite it as well.
mkdir -p "patches/nginx/${NEW}"
for f in "patches/nginx/${OLD}"/*; do
	sed "s/${OLD//./\\.}/${NEW}/g" "$f" >"patches/nginx/${NEW}/$(basename "$f" | sed "s/${OLD//./\\.}/${NEW}/")"
done

sed -i "s/^main_ver=.*/main_ver=${NEW}/" util/ver

echo -e "${BLUE}❯ ${GREEN}OpenResty now bundles nginx ${NEW} (OpenResty version $(./util/ver))${RESET}"
