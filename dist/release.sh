#!/usr/bin/env bash
WD="${PWD}"
TMP_DIR=$(mktemp -d -t next-release-XXXXX)
ZIP_NAME="${1:-next-sd-release}.zip"
ZIP_PATH="${WD}/dist/${ZIP_NAME}"
SYNC_CMD="rsync -a --exclude=README.md --exclude=*.gitkeep"
COMMIT_ID=$(git describe --tags --exclude "release-*" --always --dirty)
DWC_REPO_PATH="${2:-${WD}/DuetWebControl}"

echo "Building NeXT release ${ZIP_NAME} for ${COMMIT_ID}..."

# Make stub folder-structure
mkdir -p ${TMP_DIR}/sd/macros/system
mkdir -p ${TMP_DIR}/sd/macros/probing
mkdir -p ${TMP_DIR}/sd/macros/tooling
mkdir -p ${TMP_DIR}/sd/macros/spindle
mkdir -p ${TMP_DIR}/sd/macros/coolant
mkdir -p ${TMP_DIR}/sd/macros/utilities

# Copy macro files to correct location in temp dir
${SYNC_CMD} macros/system/* ${TMP_DIR}/sd/macros/system/
${SYNC_CMD} macros/probing/* ${TMP_DIR}/sd/macros/probing/
${SYNC_CMD} macros/tooling/* ${TMP_DIR}/sd/macros/tooling/
${SYNC_CMD} macros/spindle/* ${TMP_DIR}/sd/macros/spindle/
${SYNC_CMD} macros/coolant/* ${TMP_DIR}/sd/macros/coolant/
${SYNC_CMD} macros/utilities/* ${TMP_DIR}/sd/macros/utilities/

[[ -f "${ZIP_PATH}" ]] && rm "${ZIP_PATH}"

cd "${TMP_DIR}"

echo "Replacing %%NXT_VERSION%% with ${COMMIT_ID}..."
sed -si -e "s/%%NXT_VERSION%%/${COMMIT_ID}/g" sd/macros/system/nxt.g

# Conditionally build and include the UI if it exists
if [[ -f "${WD}/ui/plugin.json" ]]; then
    echo "UI directory found, building plugin..."

    if [[ ! -d "${DWC_REPO_PATH}" ]]; then
        echo "Duet Web Control repository not found at ${DWC_REPO_PATH}"
        exit 1
    fi

    # Copy UI source for build
    cp -r ${WD}/ui/* ${TMP_DIR}/
    sed -si -e "s/%%NXT_VERSION%%/${COMMIT_ID}/g" plugin.json

    # Build the DWC Plugin
    (   cd "${DWC_REPO_PATH}"
        npm install
        npm run build-plugin ${TMP_DIR}
        # Copy the built plugin to the main dist folder
        cp dist/NeXT-${COMMIT_ID}.zip "${WD}/dist/"
    )

    # Extract the "dwc" folder from the plugin into the SD directory
    unzip -o "${WD}/dist/NeXT-${COMMIT_ID}.zip" "dwc/*" -d "${TMP_DIR}/sd"
fi

# Create the final SD card release ZIP
(
    cd "sd"
    zip -r "${ZIP_PATH}" * -x "*.gitkeep"
)

cd "${WD}"
rm -rf "${TMP_DIR}"

echo "NeXT release created at ${ZIP_PATH}"