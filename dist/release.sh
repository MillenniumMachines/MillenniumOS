#!/usr/bin/env bash
WD="${PWD}"
TMP_DIR=$(mktemp -d -t mos-release-XXXXX)
ZIP_NAME="${1:-mos-sd-release}.zip"
ZIP_PATH="${WD}/dist/${ZIP_NAME}"
SYNC_CMD="rsync -a --exclude=README.md"
COMMIT_ID=$(git describe --tags --exclude "release-*" --always --dirty)

DWC_REPO_PATH="${2:-${WD}/DuetWebControl}"

if [[ ! -d "${DWC_REPO_PATH}" ]]; then
    echo "Duet Web Control repository not found at ${DWC_REPO_PATH}"
    exit 1
fi

echo "Building release ${ZIP_NAME} for ${COMMIT_ID}..."

# Make stub folder-structure
mkdir -p ${TMP_DIR}/sd/{sys,macros,sys/mos}
mkdir -p ${TMP_DIR}/posts

# Copy files to correct location in temp dir
${SYNC_CMD} sys/* ${TMP_DIR}/sd/sys/
${SYNC_CMD} macro/public/* ${TMP_DIR}/sd/macros/MillenniumOS
${SYNC_CMD} macro/private/* ${TMP_DIR}/sd/sys/mos
${SYNC_CMD} macro/machine/* ${TMP_DIR}/sd/sys/
${SYNC_CMD} macro/movement/* ${TMP_DIR}/sd/sys/
${SYNC_CMD} macro/tool-change/* ${TMP_DIR}/sd/sys/
${SYNC_CMD} post-processors/**/* ${TMP_DIR}/posts/
${SYNC_CMD} ui/* ${TMP_DIR}/

find ${TMP_DIR}

[[ -f "${ZIP_PATH}" ]] && rm "${ZIP_PATH}"

cd "${TMP_DIR}"

mv sd/sys/daemon.g sd/sys/daemon.install
echo "Replacing %%MOS_VERSION%% with ${COMMIT_ID}..."
sed -si -e "s/%%MOS_VERSION%%/${COMMIT_ID}/g" {plugin.json,sd/sys/*.g,posts/*}

# Copy post processors to dist
cp -v posts/* "${WD}/dist"

# Build the DWC Plugin
(
    cd "${DWC_REPO_PATH}"

    npm install
    npm run build-plugin ${TMP_DIR}

    # MillenniumOS plugin is created in the dist/ folder of the DWC repo
    cp dist/MillenniumOS-${COMMIT_ID}.zip "${WD}/dist/"
)

# Extract the "dwc" folder from the plugin into the SD directory
unzip -o "${WD}/dist/MillenniumOS-${COMMIT_ID}.zip" "dwc/*" -d "${TMP_DIR}/sd"

# Create the standalone ZIP file
(
    cd "sd"
    zip -x 'README.md' -r "${ZIP_PATH}" *
)

cd "${WD}"
rm -rf "${TMP_DIR}"