# Legacy MillenniumOS Build Process

This document outlines the build and release process for the legacy version of MillenniumOS. This is for reference purposes only, as the NeXT rewrite will use an updated process.

---

## Overview

The legacy build process consists of two main parts:
1.  **UI Plugin Compilation:** Compiling the Vue.js user interface components into a single plugin file that can be loaded by Duet Web Control (DWC).
2.  **Release Packaging:** Gathering all the macros, system files, post-processors, and the compiled UI plugin into a single `.zip` archive for distribution.

This entire process was orchestrated by the `dist/release.sh` script.

---

## 1. UI Plugin Compilation

The UI was a standard DWC plugin built using Vue.js. The compilation was handled by the DuetWebControl build system itself.

#### **Prerequisites:**
*   A local clone of the official `DuetWebControl` repository was required.
*   The path to this local repository was passed to the release script or defaulted to a sibling directory named `DuetWebControl`.

#### **Build Steps (as performed by `release.sh`):**

1.  **Navigate to DWC Repo:** The script would change into the `DuetWebControl` repository directory.
2.  **Install Dependencies:** It would run `npm install` to ensure all dependencies for the DWC build system were present.
3.  **Run Build Script:** It would then execute `npm run build-plugin <path_to_mos_ui_source>`, passing the path to a temporary directory containing the MillenniumOS `ui/` source code.
4.  **Output:** The DWC build script would compile, bundle, and output a complete plugin package named `MillenniumOS-VERSION.zip` into the `DuetWebControl/dist/` directory.

---

## 2. Release Packaging (`dist/release.sh`)

The main release script handled gathering all necessary files into a final `mos-sd-release.zip` archive.

#### **Packaging Steps:**

1.  **Create Temp Directory:** A temporary directory was created to stage the files.
2.  **Copy Files:** `rsync` was used to copy all the necessary files from the MillenniumOS repository into the correct structure within the temporary directory:
    *   `sys/*` -> `sd/sys/`
    *   `macro/public/*` -> `sd/macros/MillenniumOS/`
    *   `macro/private/*` -> `sd/sys/mos/`
    *   Other `macro` subdirectories -> `sd/sys/`
    *   `post-processors/**/*` -> `posts/`
    *   `ui/*` -> (root of temp dir, for the build process)
3.  **Versioning:** The script used `sed` to replace the `%%MOS_VERSION%%` placeholder with the current Git commit ID in all `.g` files and the `plugin.json`.
4.  **UI Integration:**
    *   After the UI plugin was built (as described above), the script would copy the final `MillenniumOS-VERSION.zip` to the main project's `dist/` folder.
    *   It would then `unzip` only the `dwc/*` contents from that plugin zip into the `sd/` directory being staged for the final release. This embedded the compiled UI assets into the main package.
    *   **Plugin Activation (`dwc-plugins.json`):** The script would then extract the names of the generated Webpack chunk files from the UI build. These details were written to a `dwc-plugins.json` file, which was placed in the `sd/sys/` folder. This file served to "activate" the plugin, allowing DWC to automatically enable it upon first boot after extracting the SD card contents.
5.  **Final Zip Creation:** The script would navigate into the `sd/` directory and create the final `mos-sd-release.zip`, containing the macros, system files, and the compiled UI, ready for distribution.
