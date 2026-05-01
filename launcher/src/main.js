const { app, BrowserWindow, ipcMain, shell } = require('electron');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const AdmZip = require('adm-zip');

const REPO = 'xian0310567/wallborn';
const RELEASE_TAG = 'latest-test-build';
const MAC_ASSET = 'Wallborn.zip';
const WINDOWS_ASSET = 'Wallborn.exe';

let mainWindow;

function paths() {
  const root = app.getPath('userData');
  return {
    root,
    config: path.join(root, 'config.json'),
    downloads: path.join(root, 'downloads'),
    builds: path.join(root, 'builds'),
    latest: path.join(root, 'builds', 'latest'),
  };
}

function ensureDirs() {
  const p = paths();
  fs.mkdirSync(p.downloads, { recursive: true });
  fs.mkdirSync(p.builds, { recursive: true });
  fs.mkdirSync(p.latest, { recursive: true });
}

function readConfig() {
  try {
    return JSON.parse(fs.readFileSync(paths().config, 'utf8'));
  } catch {
    return { installedAssetUpdatedAt: '' };
  }
}

function writeConfig(config) {
  ensureDirs();
  fs.writeFileSync(paths().config, JSON.stringify(config, null, 2));
}

function githubHeaders(accept = 'application/vnd.github+json') {
  return {
    'Accept': accept,
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'Wallborn-Test-Launcher',
  };
}

async function fetchLatestRelease() {
  const response = await fetch(`https://api.github.com/repos/${REPO}/releases/tags/${RELEASE_TAG}`, {
    headers: githubHeaders(),
  });
  if (!response.ok) {
    throw new Error(`GitHub release request failed: ${response.status} ${response.statusText}`);
  }
  const release = await response.json();
  const wantedAsset = process.platform === 'darwin' ? MAC_ASSET : WINDOWS_ASSET;
  const asset = release.assets.find((item) => item.name === wantedAsset);
  if (!asset) throw new Error(`Release asset not found: ${wantedAsset}`);
  return {
    tag: release.tag_name,
    name: release.name,
    htmlUrl: release.html_url,
    body: release.body || '',
    assetName: asset.name,
    assetId: asset.id,
    assetUpdatedAt: asset.updated_at,
    assetSize: asset.size,
    browserDownloadUrl: asset.browser_download_url,
  };
}

async function downloadAsset(url, outputPath) {
  const response = await fetch(url, { headers: githubHeaders('application/octet-stream') });
  if (!response.ok) {
    throw new Error(`Download failed: ${response.status} ${response.statusText}`);
  }
  const buffer = Buffer.from(await response.arrayBuffer());
  fs.writeFileSync(outputPath, buffer);
}

function clearDir(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
}

function findFirst(dir, predicate) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (predicate(fullPath, entry)) return fullPath;
    if (entry.isDirectory()) {
      const nested = findFirst(fullPath, predicate);
      if (nested) return nested;
    }
  }
  return null;
}

async function installLatestBuild() {
  ensureDirs();
  const config = readConfig();
  const release = await fetchLatestRelease();
  const p = paths();
  const output = path.join(p.downloads, release.assetName);
  await downloadAsset(release.browserDownloadUrl, output);

  clearDir(p.latest);
  if (release.assetName.endsWith('.zip')) {
    const zip = new AdmZip(output);
    zip.extractAllTo(p.latest, true);
  } else {
    fs.copyFileSync(output, path.join(p.latest, release.assetName));
  }

  writeConfig({ ...config, installedAssetUpdatedAt: release.assetUpdatedAt });
  return { release, installPath: p.latest };
}

function launchInstalledBuild() {
  const p = paths();
  if (process.platform === 'darwin') {
    const appPath = findFirst(p.latest, (fullPath, entry) => entry.isDirectory() && fullPath.endsWith('.app'));
    if (!appPath) throw new Error('No .app found. Run Update first.');
    spawn('open', [appPath], { detached: true, stdio: 'ignore' }).unref();
    return appPath;
  }

  if (process.platform === 'win32') {
    const exePath = findFirst(p.latest, (fullPath, entry) => entry.isFile() && entry.name === WINDOWS_ASSET);
    if (!exePath) throw new Error('No Wallborn.exe found. Run Update first.');
    spawn(exePath, [], { detached: true, stdio: 'ignore' }).unref();
    return exePath;
  }

  throw new Error(`Unsupported platform: ${process.platform}`);
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 860,
    height: 560,
    title: 'Wallborn Test Launcher',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  mainWindow.loadFile(path.join(__dirname, 'index.html'));
}

ipcMain.handle('config:get', () => {
  const config = readConfig();
  return { installedAssetUpdatedAt: config.installedAssetUpdatedAt || '' };
});

ipcMain.handle('release:check', async () => fetchLatestRelease());

ipcMain.handle('build:update', async () => installLatestBuild());

ipcMain.handle('build:launch', async () => launchInstalledBuild());

ipcMain.handle('paths:open-user-data', async () => {
  ensureDirs();
  await shell.openPath(paths().root);
  return paths().root;
});

app.whenReady().then(() => {
  ensureDirs();
  createWindow();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});