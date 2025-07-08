#!/usr/bin/env bash

[[ ! -f "package.json" ]] && echo "Please run this script from the root of Duet Web Control!" && exit 1

# Get version from git
COMMIT_ID=$(cd .. && git describe --tags --exclude "release-*" --always --dirty)
echo "Building MillenniumOS UI plugin with version ${COMMIT_ID}..."

# Copy version to plugin.json
sed -i "s/\"version\": \"auto\"/\"version\": \"${COMMIT_ID}\"/g" ../ui/src/plugin.json

npm install
npm run build-plugin ../ui