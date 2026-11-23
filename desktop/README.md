# VDL Dashboard desktop app

A small Windows program that opens the VDL Dashboard in its own window, with the firm's VD monogram, a Start menu entry and a desktop shortcut. It holds no data itself: it connects to the dashboard server over the network, so every PC sees the same dashboard.

## Install on a PC

1. Open the repository's **Releases** page and download `VDL-Dashboard-Setup-<version>.exe` from the latest `desktop-v…` release.
2. Run it. The installer is not code-signed yet, so Windows SmartScreen may say "Windows protected your PC". Click **More info**, then **Run anyway**.
3. On first start, enter the server address and click **Save and open**.

The address can be changed at any time under **File > Server settings…** (Ctrl+,). It is stored per Windows user in `%APPDATA%\VDL Dashboard\config.json`.

If the server cannot be reached, the app shows a "Cannot reach the dashboard" screen and retries every 15 seconds.

## Server address rules

- An online server must use `https://`, so passwords and client data are encrypted on the way. The app refuses a plain `http://` address for any host other than the PC itself.
- `http://localhost:3000` (or `127.0.0.1`) is allowed, for the PC that runs the server.
- Typing an address without `https://` adds it automatically (or `http://` for localhost).

## Pre-fill the server address for the whole firm

Once the dashboard is hosted online, build an installer that already suggests the right address, so staff only click **Save and open**:

- set a repository variable `DASHBOARD_SERVER_URL` (Settings > Secrets and variables > Actions > Variables), or
- run the **Desktop app (Windows installer)** workflow by hand and fill in **server_url**.

The address can also be set with the `VDL_DASHBOARD_URL` environment variable.

## Security

- The dashboard runs in a sandboxed window with context isolation and no Node.js access.
- The window may only navigate within the configured server. Links to any other site open in the normal browser, and pop-ups from the server open in another locked-down window.
- The app's own screens (server settings, offline) are served from a private `app://` scheme with a strict Content Security Policy, and only those screens can talk to the app.
- Electron fuses are set at build time: no `ELECTRON_RUN_AS_NODE`, no `NODE_OPTIONS`, no `--inspect`, app code only from `app.asar`, checked against its integrity hash, and cookie encryption on, so the session cookie on disk is encrypted with the Windows user's key.

## Before rollout: code signing

The installer is unsigned, so SmartScreen warns on every PC until the download builds a reputation. Before rolling out to the whole firm, buy a code signing certificate (an OV certificate, or Azure Trusted Signing) and add it to the workflow (`CSC_LINK` and `CSC_KEY_PASSWORD` secrets for electron-builder, or the Azure signing action).

## How releases are built

The `Desktop app (Windows installer)` workflow builds the installer on `windows-latest` for every pull request that touches `desktop/`. When such a change lands on `dev`, it also publishes the installer as a GitHub release tagged `desktop-v<version>`. Bump `version` in `package.json` to publish a new release; without a bump, the existing release's installer is replaced.

## Develop

```sh
cd desktop
npm install
npm start     # run the app
npm test      # unit tests
npm run dist  # build the installer into dist/ (Windows, or Linux with Wine)
```

## Icon

`build/icon.png` (512×512) and `build/icon.ico` are made from `docs/law-firm/brand/vdl-icon-square-charcoal.png` with rounded corners:

```sh
magick ../docs/law-firm/brand/vdl-icon-square-charcoal.png -resize 512x512 \
  \( -size 512x512 xc:none -fill white -draw "roundrectangle 0,0,511,511,96,96" \) \
  -compose DstIn -composite build/icon.png
magick build/icon.png -define icon:auto-resize=256,128,64,48,32,16 build/icon.ico
```
