const statusEl = document.querySelector('#status');
const releaseEl = document.querySelector('#release');
const installedEl = document.querySelector('#installed');

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
  installedEl.textContent = formatKst(config.installedAssetUpdatedAt);
}

async function run(label, task) {
  try {
    log(`${label}...`);
    const result = await task();
    log(`${label} 완료`);
    await refreshConfig();
    return result;
  } catch (error) {
    log(`${label} 실패: ${error.message}`);
    throw error;
  }
}

document.querySelector('#check').addEventListener('click', async () => {
  const release = await run('최신 빌드 확인', () => window.wallborn.checkRelease());
  renderRelease(release);
});

document.querySelector('#update').addEventListener('click', async () => {
  const result = await run('최신 빌드 다운로드/설치', () => window.wallborn.updateBuild());
  renderRelease(result.release, `설치 위치: ${result.installPath}`);
});

document.querySelector('#launch').addEventListener('click', async () => {
  const launchedPath = await run('Wallborn 실행', () => window.wallborn.launchBuild());
  releaseEl.textContent = `실행: ${launchedPath}`;
});

document.querySelector('#open-folder').addEventListener('click', async () => {
  const folder = await window.wallborn.openUserData();
  log(`런처 폴더 열기: ${folder}`);
});

refreshConfig();
