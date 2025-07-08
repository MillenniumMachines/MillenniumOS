#!/usr/bin/env bash
WD="${PWD}"
TMP_DIR=$(mktemp -d -t mos-release-XXXXX)
ZIP_NAME="${1:-mos-release}.zip"
ZIP_PATH="${WD}/dist/${ZIP_NAME}"
SYNC_CMD="rsync -a --exclude=README.md"
COMMIT_ID=$(git describe --tags --exclude "release-*" --always --dirty)
UI_SD_DIR="${WD}/ui/sd"

echo "Building release ${ZIP_NAME} for ${COMMIT_ID}..."

# Make stub folder-structure
mkdir -p ${TMP_DIR}/{sys,macros,sys/mos,posts}
# Also ensure UI sd directory exists
mkdir -p ${UI_SD_DIR}/{sys,macros,sys/mos,posts}

# Copy files to correct location in temp dir
${SYNC_CMD} sys/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/public/* ${TMP_DIR}/macros/MillenniumOS
${SYNC_CMD} macro/private/* ${TMP_DIR}/sys/mos
${SYNC_CMD} macro/machine/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/movement/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/tool-change/* ${TMP_DIR}/sys/
${SYNC_CMD} post-processors/**/* ${TMP_DIR}/posts/

# Also copy files to UI plugin sd directory
${SYNC_CMD} sys/* ${UI_SD_DIR}/sys/
${SYNC_CMD} macro/public/* ${UI_SD_DIR}/macros/MillenniumOS
${SYNC_CMD} macro/private/* ${UI_SD_DIR}/sys/mos
${SYNC_CMD} macro/machine/* ${UI_SD_DIR}/sys/
${SYNC_CMD} macro/movement/* ${UI_SD_DIR}/sys/
${SYNC_CMD} macro/tool-change/* ${UI_SD_DIR}/sys/

find ${TMP_DIR}

[[ -f "${ZIP_PATH}" ]] && rm "${ZIP_PATH}"

cd "${TMP_DIR}"
mv sys/daemon.g sys/daemon.install
echo "Replacing %%MOS_VERSION%% with ${COMMIT_ID}..."
sed -si -e "s/%%MOS_VERSION%%/${COMMIT_ID}/g" {sys/*.g,posts/*}

# Also do version replacement in the UI sd directory
cd "${UI_SD_DIR}"
mv sys/daemon.g sys/daemon.install
echo "Replacing %%MOS_VERSION%% with ${COMMIT_ID} in UI plugin files..."
sed -si -e "s/%%MOS_VERSION%%/${COMMIT_ID}/g" sys/*.g

cd "${TMP_DIR}"
cp -v posts/* "${WD}/dist"
zip -x 'README.md' -x 'posts/' -x 'posts/**' -r "${ZIP_PATH}" *
cd "${WD}"
rm -rf "${TMP_DIR}"
