const statusEl = document.querySelector('#status');
const releaseEl = document.querySelector('#release');

function log(message) {
  statusEl.textContent = message;
}

async function refreshConfig() {
  const config = await window.wallborn.getConfig();
  document.querySelector('#installed').textContent = config.installedAssetUpdatedAt || '미설치';
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
  releaseEl.textContent = JSON.stringify(release, null, 2);
});

document.querySelector('#update').addEventListener('click', async () => {
  const result = await run('최신 빌드 다운로드/설치', () => window.wallborn.updateBuild());
  releaseEl.textContent = JSON.stringify(result, null, 2);
});

document.querySelector('#launch').addEventListener('click', async () => {
  const launchedPath = await run('Wallborn 실행', () => window.wallborn.launchBuild());
  releaseEl.textContent = `실행: ${launchedPath}`;
});

document.querySelector('#open-folder').addEventListener('click', async () => {
  const folder = await window.wallborn.openUserData();
  log(`폴더 열기: ${folder}`);
});

refreshConfig();