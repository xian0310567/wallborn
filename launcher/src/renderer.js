const statusEl = document.querySelector('#status');
const releaseEl = document.querySelector('#release');
const installedEl = document.querySelector('#installed');
const latestEl = document.querySelector('#latest');
const updateStateEl = document.querySelector('#update-state');
const lastCheckEl = document.querySelector('#last-check');
const updateButton = document.querySelector('#update');

const CHECK_INTERVAL_MS = 60 * 1000;
let latestRelease = null;
let installedAssetUpdatedAt = '';
let checking = false;

function formatKst(value) {
  if (!value) return '설치된 빌드 없음';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat('ko-KR', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
    timeZoneName: 'short',
  }).format(date);
}

function log(message) {
  statusEl.textContent = message;
}

function isUpdateAvailable(installedAt, latestAt) {
  if (!latestAt) return false;
  if (!installedAt) return true;
  return new Date(latestAt).getTime() > new Date(installedAt).getTime();
}

function setUpdateState(kind, message) {
  updateStateEl.className = `state ${kind}`.trim();
  updateStateEl.textContent = message;
}

function renderRelease(release, extra = '') {
  if (!release) {
    releaseEl.textContent = '';
    return;
  }
  releaseEl.textContent = [
    `태그: ${release.tag}`,
    `이름: ${release.name}`,
    `빌드 갱신 시간: ${formatKst(release.assetUpdatedAt)}`,
    `파일: ${release.assetName}`,
    `크기: ${Math.round((release.assetSize || 0) / 1024 / 1024)} MB`,
    `링크: ${release.htmlUrl}`,
    release.body ? `메모:\n${release.body}` : '',
    extra,
  ].filter(Boolean).join('\n');
}

async function refreshConfig() {
  const config = await window.wallborn.getConfig();
  installedAssetUpdatedAt = config.installedAssetUpdatedAt || '';
  installedEl.textContent = formatKst(installedAssetUpdatedAt);
  return config;
}

function updateAvailabilityUi() {
  const latestAt = latestRelease?.assetUpdatedAt || '';
  latestEl.textContent = latestAt ? formatKst(latestAt) : '확인 필요';

  const available = isUpdateAvailable(installedAssetUpdatedAt, latestAt);
  updateButton.disabled = !available;
  updateButton.classList.toggle('update-available', available);

  if (!latestRelease) {
    setUpdateState('', '최신 빌드 확인 필요');
  } else if (available) {
    setUpdateState('update', '새 빌드 있음 — 업데이트 가능');
  } else {
    setUpdateState('latest', '최신 빌드 설치됨');
  }
}

async function checkForUpdates({ manual = false } = {}) {
  if (checking) return latestRelease;
  checking = true;
  try {
    if (manual) log('최신 빌드 확인...');
    await refreshConfig();
    latestRelease = await window.wallborn.checkRelease();
    lastCheckEl.textContent = formatKst(new Date().toISOString());
    updateAvailabilityUi();
    renderRelease(latestRelease);
    if (manual) log('최신 빌드 확인 완료');
    return latestRelease;
  } catch (error) {
    setUpdateState('error', `확인 실패: ${error.message}`);
    if (manual) log(`최신 빌드 확인 실패: ${error.message}`);
    throw error;
  } finally {
    checking = false;
  }
}

async function run(label, task) {
  try {
    log(`${label}...`);
    const result = await task();
    log(`${label} 완료`);
    await refreshConfig();
    updateAvailabilityUi();
    return result;
  } catch (error) {
    log(`${label} 실패: ${error.message}`);
    throw error;
  }
}

document.querySelector('#check').addEventListener('click', async () => {
  await checkForUpdates({ manual: true });
});

updateButton.addEventListener('click', async () => {
  const result = await run('최신 빌드 다운로드/설치', () => window.wallborn.updateBuild());
  latestRelease = result.release;
  renderRelease(result.release, `설치 위치: ${result.installPath}`);
  updateAvailabilityUi();
});

document.querySelector('#launch').addEventListener('click', async () => {
  const launchedPath = await run('Wallborn 실행', () => window.wallborn.launchBuild());
  releaseEl.textContent = `실행: ${launchedPath}`;
});

document.querySelector('#open-folder').addEventListener('click', async () => {
  const folder = await window.wallborn.openUserData();
  log(`런처 폴더 열기: ${folder}`);
});

window.addEventListener('focus', () => {
  checkForUpdates().catch(() => {});
});

document.addEventListener('visibilitychange', () => {
  if (!document.hidden) checkForUpdates().catch(() => {});
});

refreshConfig()
  .then(() => checkForUpdates())
  .catch((error) => log(`초기 확인 실패: ${error.message}`));

setInterval(() => {
  checkForUpdates().catch(() => {});
}, CHECK_INTERVAL_MS);
