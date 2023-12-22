#!/usr/bin/env bash
WD="${PWD}"
echo "Building release zip..."
TMPDIR=$(mktemp -d -t mos-release-XXXXX)
SYNC_CMD="rsync -a --exclude=README.md"

# Make stub folder-structure
mkdir -p ${TMPDIR}/{sys,macros,sys/mos}

# Copy files to correct location in temp dir
${SYNC_CMD} sys/* ${TMPDIR}/sys/
${SYNC_CMD} macro/public/* ${TMPDIR}/macros/
${SYNC_CMD} macro/private/* ${TMPDIR}/sys/mos
${SYNC_CMD} macro/machine/* ${TMPDIR}/sys/
${SYNC_CMD} macro/movement/* ${TMPDIR}/sys/

find ${TMPDIR}

[[ -f mos-release.zip ]] && rm mos-release.zip

cd "${TMPDIR}" && mv sys/daemon.g sys/daemon.install && zip -x 'README.md' -r "${WD}/mos-release.zip" * && cd "${WD}"

rm -rf "${TMPDIR}"