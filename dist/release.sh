#!/usr/bin/env bash
WD="${PWD}"
TMP_DIR=$(mktemp -d -t mos-release-XXXXX)
ZIP_NAME="${1:-mos-release}.zip"
SYNC_CMD="rsync -a --exclude=README.md"

echo "Building release ${ZIP_NAME}..."

# Make stub folder-structure
mkdir -p ${TMP_DIR}/{sys,macros,sys/mos}

# Copy files to correct location in temp dir
${SYNC_CMD} sys/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/public/* ${TMP_DIR}/macros/MillenniumOS
${SYNC_CMD} macro/private/* ${TMP_DIR}/sys/mos
${SYNC_CMD} macro/machine/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/movement/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/tool-change/* ${TMP_DIR}/sys/

find ${TMP_DIR}

[[ -f ${ZIP_NAME} ]] && rm ${ZIP_NAME}

cd "${TMP_DIR}" && mv sys/daemon.g sys/daemon.install && zip -x 'README.md' -r "${WD}/${ZIP_NAME}" * && cd "${WD}"

rm -rf "${TMP_DIR}"