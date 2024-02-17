#!/usr/bin/env bash
WD="${PWD}"
TMP_DIR=$(mktemp -d -t mos-release-XXXXX)
ZIP_NAME="${1:-mos-release}.zip"
SYNC_CMD="rsync -a --exclude=README.md"
COMMIT_ID=$(git describe --tags --exclude "release-*" --always --dirty)

echo "Building release ${ZIP_NAME} for ${COMMIT_ID}..."

# Make stub folder-structure
mkdir -p ${TMP_DIR}/{sys,macros,sys/mos,posts}

# Copy files to correct location in temp dir
${SYNC_CMD} sys/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/public/* ${TMP_DIR}/macros/MillenniumOS
${SYNC_CMD} macro/private/* ${TMP_DIR}/sys/mos
${SYNC_CMD} macro/machine/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/movement/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/tool-change/* ${TMP_DIR}/sys/
${SYNC_CMD} post-processors/**/* ${TMP_DIR}/posts/

find ${TMP_DIR}

[[ -f ${ZIP_NAME} ]] && rm ${ZIP_NAME}

cd "${TMP_DIR}"
mv sys/daemon.g sys/daemon.install
echo "Replacing %%MOS_VERSION%% with ${COMMIT_ID}..."
sed --debug -si -e "s/%%MOS_VERSION%%/${COMMIT_ID}/g" {sys/mos.g,posts/*}
cp -v posts/* "${WD}/dist"
zip -x 'README.md' -x 'posts/' -x 'posts/**' -r "${WD}/dist/${ZIP_NAME}" *
cd "${WD}"
rm -rf "${TMP_DIR}"