# Law Firm Dashboard desktop app

A small Windows program that opens the Law Firm Dashboard in its own window, with its own icon, Start menu entry and desktop shortcut. It holds no data itself: it connects to the dashboard server over the network, so every PC sees the same dashboard.

## Install on a PC

1. Open the repository's **Releases** page and download `Law-Firm-Dashboard-Setup-<version>.exe` from the latest `desktop-v…` release.
2. Run it. The installer is not code-signed yet, so Windows SmartScreen may say "Windows protected your PC". Click **More info**, then **Run anyway**.
3. On first start, enter the server address and click **Save and open**. On the PC that runs the server this is `http://localhost:3000`; on other PCs it is the online address of the server.

The address can be changed at any time under **File > Server settings…** (Ctrl+,). It is stored per Windows user in `%APPDATA%\Law Firm Dashboard\config.json`.

If the server cannot be reached, the app shows a "Cannot reach the dashboard" screen and retries every 15 seconds.

## Pre-fill the server address for the whole firm

Once the dashboard is hosted online, build an installer that already suggests the right address, so staff only click **Save and open**:

- set a repository variable `DASHBOARD_SERVER_URL` (Settings > Secrets and variables > Actions > Variables), or
- run the **Desktop app (Windows installer)** workflow by hand and fill in **server_url**.

The address can also be forced with the `LAW_FIRM_DASHBOARD_URL` environment variable.

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

## Logo

`build/icon.svg` is a placeholder (gold scales on navy). To use the firm's logo, replace `build/icon.png` (512×512) and `build/icon.ico` (16 to 256 px sizes), for example with ImageMagick:

```sh
magick logo.png -resize 512x512 build/icon.png
magick build/icon.png -define icon:auto-resize=256,128,64,48,32,16 build/icon.ico
```
