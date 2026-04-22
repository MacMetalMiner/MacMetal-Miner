/**
 * NEX Browser Miner — Multi-threaded Stratum controller
 * Spawns one Web Worker per CPU core for maximum hashrate.
 */

const WS_URL = location.hostname === 'localhost' || location.hostname === '127.0.0.1'
  ? 'ws://localhost:8765'
  : (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws';

const NUM_THREADS = navigator.hardwareConcurrency || 4;

let ws = null;
let workers = [];
let extranonce1 = '';
let extranonce2Size = 4;
let currentDifficulty = 0.001;
let currentJob = null;
let minerAddress = '';
let msgId = 1;
let sharesAccepted = 0;
let sharesRejected = 0;
let startTime = 0;
let totalHashrate = 0;
let connected = false;
let mining = false;

// Per-worker hashrate tracking
let workerHashrates = {};

function $(id) { return document.getElementById(id); }

function log(msg) {
  const el = $('log');
  const time = new Date().toLocaleTimeString();
  el.innerHTML += `<div><span style="color:#666">${time}</span> ${msg}</div>`;
  el.scrollTop = el.scrollHeight;
}

function updateStats() {
  totalHashrate = Object.values(workerHashrates).reduce((a, b) => a + b, 0);
  $('hashrate').textContent = formatHashrate(totalHashrate);
  $('accepted').textContent = sharesAccepted;
  $('rejected').textContent = sharesRejected;
  $('difficulty').textContent = currentDifficulty.toLocaleString();
  $('threads').textContent = mining ? `${workers.length} threads` : '0 threads';
  if (startTime > 0) {
    const secs = Math.floor((Date.now() - startTime) / 1000);
    const h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60), s = secs % 60;
    $('elapsed').textContent = h > 0 ? `${h}h ${m}m ${s}s` : m > 0 ? `${m}m ${s}s` : `${s}s`;
  }
  const sp = $('statusPill');
  if (sp) {
    if (mining) sp.innerHTML = '<span class="status-pill mining"><span class="status-dot on"></span>Mining</span>';
    else if (connected) sp.innerHTML = '<span class="status-pill mining"><span class="status-dot on"></span>Connected</span>';
    else sp.innerHTML = '<span class="status-pill idle"><span class="status-dot off"></span>Idle</span>';
  }
  const ls = $('logStatus');
  if (ls) ls.textContent = mining ? 'active' : connected ? 'connected' : 'idle';
}

function formatHashrate(h) {
  if (h >= 1e9) return (h / 1e9).toFixed(2) + ' GH/s';
  if (h >= 1e6) return (h / 1e6).toFixed(2) + ' MH/s';
  if (h >= 1e3) return (h / 1e3).toFixed(2) + ' KH/s';
  return Math.floor(h) + ' H/s';
}

// ── Stratum protocol ──
function sendStratum(method, params) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  ws.send(JSON.stringify({ id: msgId++, method, params }));
}

function handleStratumMessage(data) {
  let msg;
  try { msg = JSON.parse(data); } catch { return; }
  if (msg.id && msg.result !== undefined) { handleResponse(msg); return; }
  if (msg.method) handleNotification(msg);
}

function handleResponse(msg) {
  if (msg.result && Array.isArray(msg.result) && msg.result.length === 3 && Array.isArray(msg.result[0])) {
    extranonce1 = msg.result[1];
    extranonce2Size = msg.result[2];
    log(`Subscribed — extranonce1: <span style="color:#0f0">${extranonce1}</span>`);
    sendStratum('mining.authorize', [minerAddress + '.WebMiner', 'x']);
    return;
  }
  if (msg.result === true && !mining) {
    log(`Authorized as <span style="color:#0f0">${minerAddress}</span>`);
    return;
  }
  if (msg.result === true) {
    sharesAccepted++;
    log(`Share <span style="color:#0f0">accepted</span> (${sharesAccepted} total)`);
  } else if (msg.error) {
    sharesRejected++;
    log(`Share <span style="color:#f55">rejected</span>: ${msg.error[1] || 'unknown'}`);
  }
}

function handleNotification(msg) {
  switch (msg.method) {
    case 'mining.set_difficulty':
      currentDifficulty = msg.params[0];
      log(`Difficulty: <span style="color:#ff0">${currentDifficulty}</span>`);
      workers.forEach(w => w.postMessage({ type: 'difficulty', difficulty: currentDifficulty }));
      break;

    case 'mining.notify':
      const p = msg.params;
      currentJob = {
        jobId: p[0], prevhash: p[1], coinbase1: p[2], coinbase2: p[3],
        merkleBranches: p[4], version: p[5], nbits: p[6], ntime: p[7], cleanJobs: p[8]
      };
      log(`Job: <span style="color:#0ff">${currentJob.jobId}</span> — ${workers.length} threads hashing`);
      if (!mining) { mining = true; startTime = Date.now(); }
      dispatchJobToWorkers();
      break;

    case 'mining.block_found':
      const [hash, height, reward] = msg.params;
      log(`<span style="color:#ffd700;font-weight:bold">BLOCK FOUND! #${height} — ${reward} NEX</span>`);
      break;
  }
}

// ── Multi-worker management ──
function dispatchJobToWorkers() {
  if (!currentJob) return;
  // Each worker gets the same job but a unique extranonce2 prefix so they search different nonce space
  workers.forEach((w, i) => {
    w.postMessage({
      type: 'job',
      job: currentJob,
      extranonce1: extranonce1,
      difficulty: currentDifficulty,
      workerId: i,
      totalWorkers: workers.length
    });
  });
}

function startWorkers() {
  stopWorkers();
  const count = NUM_THREADS;
  log(`Starting <span style="color:#0ff">${count}</span> mining threads (${count} CPU cores)`);

  for (let i = 0; i < count; i++) {
    const w = new Worker('worker.js');

    w.onmessage = function(e) {
      const msg = e.data;
      if (msg.type === 'share') {
        sendStratum('mining.submit', [
          minerAddress + '.WebMiner',
          msg.jobId, msg.extranonce2, msg.ntime, msg.nonce
        ]);
        log(`Share found on thread ${msg.workerId} — nonce: <span style="color:#ff0">${msg.nonce}</span>`);
      }
      if (msg.type === 'hashrate') {
        workerHashrates[msg.workerId] = msg.hashrate;
      }
      if (msg.type === 'log') {
        log(`<span style="color:#888">[worker ${i}] ${msg.msg}</span>`);
      }
      if (msg.type === 'error') {
        log(`<span style="color:#f55;font-weight:bold">[worker ${i}] ${msg.msg}</span>`);
      }
    };

    w.postMessage({ type: 'start' });
    workers.push(w);
  }
}

function stopWorkers() {
  workers.forEach(w => { w.postMessage({ type: 'stop' }); w.terminate(); });
  workers = [];
  workerHashrates = {};
}

// ── Public API ──
window.startMining = function() {
  minerAddress = $('address').value.trim();
  if (!minerAddress) { log('<span style="color:#f55">Enter a NEX address first</span>'); return; }

  log('Connecting to pool...');
  $('startBtn').disabled = true;
  $('stopBtn').disabled = false;
  $('address').disabled = true;

  ws = new WebSocket(WS_URL);

  ws.onopen = function() {
    connected = true;
    log('Connected to pool');
    sendStratum('mining.subscribe', ['NEXWebMiner/1.0']);
    startWorkers();
  };
  ws.onmessage = function(e) { handleStratumMessage(e.data); };
  ws.onclose = function() {
    connected = false; mining = false;
    log('<span style="color:#f55">Disconnected from pool</span>');
    $('startBtn').disabled = false; $('stopBtn').disabled = true; $('address').disabled = false;
    stopWorkers();
  };
  ws.onerror = function() { log('<span style="color:#f55">Connection error</span>'); };
};

window.stopMining = function() {
  mining = false;
  stopWorkers();
  if (ws) { ws.close(); ws = null; }
  connected = false; totalHashrate = 0;
  log('Mining stopped');
  $('startBtn').disabled = false; $('stopBtn').disabled = true; $('address').disabled = false;
};

setInterval(updateStats, 1000);
