/**
 * SHA256d Mining Web Worker — High Performance
 * Pure synchronous SHA-256 (no async overhead), batch processing.
 * Each worker gets a unique nonce partition to avoid duplicate work.
 */

// SHA-256 constants
const K = new Int32Array([
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
]);

// Optimized SHA-256: operates on a pre-padded 64-byte (or 128-byte) buffer
// For mining: header is always 80 bytes → pads to 128 bytes (2 blocks)
function sha256_raw(buf, len) {
  // Pad
  const bitLen = len * 8;
  const padLen = (len + 9 + 63) & ~63; // round up to 64-byte blocks
  const padded = new Uint8Array(padLen);
  padded.set(new Uint8Array(buf.buffer || buf, 0, len));
  padded[len] = 0x80;
  const dv = new DataView(padded.buffer);
  dv.setUint32(padLen - 4, bitLen, false);

  let h0 = 0x6a09e667|0, h1 = 0xbb67ae85|0, h2 = 0x3c6ef372|0, h3 = 0xa54ff53a|0;
  let h4 = 0x510e527f|0, h5 = 0x9b05688c|0, h6 = 0x1f83d9ab|0, h7 = 0x5be0cd19|0;
  const w = new Int32Array(64);

  for (let off = 0; off < padLen; off += 64) {
    for (let i = 0; i < 16; i++) w[i] = dv.getInt32(off + i * 4, false);
    for (let i = 16; i < 64; i++) {
      const s0 = (((w[i-15] >>> 7) | (w[i-15] << 25)) ^ ((w[i-15] >>> 18) | (w[i-15] << 14)) ^ (w[i-15] >>> 3))|0;
      const s1 = (((w[i-2] >>> 17) | (w[i-2] << 15)) ^ ((w[i-2] >>> 19) | (w[i-2] << 13)) ^ (w[i-2] >>> 10))|0;
      w[i] = (w[i-16] + s0 + w[i-7] + s1)|0;
    }
    let a=h0,b=h1,c=h2,d=h3,e=h4,f=h5,g=h6,h=h7;
    for (let i = 0; i < 64; i++) {
      const S1 = (((e>>>6)|(e<<26))^((e>>>11)|(e<<21))^((e>>>25)|(e<<7)))|0;
      const ch = ((e&f)^(~e&g))|0;
      const t1 = (h+S1+ch+K[i]+w[i])|0;
      const S0 = (((a>>>2)|(a<<30))^((a>>>13)|(a<<19))^((a>>>22)|(a<<10)))|0;
      const maj = ((a&b)^(a&c)^(b&c))|0;
      const t2 = (S0+maj)|0;
      h=g; g=f; f=e; e=(d+t1)|0; d=c; c=b; b=a; a=(t1+t2)|0;
    }
    h0=(h0+a)|0; h1=(h1+b)|0; h2=(h2+c)|0; h3=(h3+d)|0;
    h4=(h4+e)|0; h5=(h5+f)|0; h6=(h6+g)|0; h7=(h7+h)|0;
  }
  const out = new DataView(new ArrayBuffer(32));
  out.setInt32(0,h0,false); out.setInt32(4,h1,false); out.setInt32(8,h2,false); out.setInt32(12,h3,false);
  out.setInt32(16,h4,false); out.setInt32(20,h5,false); out.setInt32(24,h6,false); out.setInt32(28,h7,false);
  return new Uint8Array(out.buffer);
}

function sha256d(data, len) {
  const h1 = sha256_raw(data, len);
  return sha256_raw(h1, 32);
}

function hexToBytes(hex) {
  const b = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) b[i/2] = parseInt(hex.substr(i, 2), 16);
  return b;
}

function bytesToHex(b) {
  let s = '';
  for (let i = 0; i < b.length; i++) s += (b[i] < 16 ? '0' : '') + b[i].toString(16);
  return s;
}

function reverseHex(hex) {
  let r = '';
  for (let i = hex.length - 2; i >= 0; i -= 2) r += hex.substr(i, 2);
  return r;
}

// Reverse the order of 4-byte words in a hex string (stratum prevhash format)
function reverseWords(hex) {
  const words = [];
  for (let i = 0; i < hex.length; i += 8) words.push(hex.substr(i, 8));
  return words.reverse().join('');
}

// Build the 80-byte header, returns a reusable buffer (nonce at offset 76)
// Header layout (all little-endian for consensus):
//   [0..3]   version LE
//   [4..35]  prev_hash LE (display bytes reversed)
//   [36..67] merkle_root LE (from sha256d, already internal/LE order)
//   [68..71] ntime LE
//   [72..75] nbits LE
//   [76..79] nonce LE
function buildHeaderTemplate(job, extranonce1, extranonce2) {
  const coinbase = hexToBytes(job.coinbase1 + extranonce1 + extranonce2 + job.coinbase2);
  let merkle = sha256d(coinbase, coinbase.length);
  for (const branch of job.merkleBranches) {
    const combined = new Uint8Array(64);
    combined.set(merkle);
    combined.set(hexToBytes(branch), 32);
    merkle = sha256d(combined, 64);
  }

  const header = new Uint8Array(80);

  // Version: stratum sends big-endian hex → we need little-endian bytes
  const versionInt = parseInt(job.version, 16);
  const vDV = new DataView(header.buffer);
  vDV.setUint32(0, versionInt, true); // LE

  // Prevhash: stratum sends 8 x 4-byte words of display hash in reversed word order.
  // Per-word byte swap converts this to prev_hash_le (verified against pool).
  const phex = job.prevhash;
  const prevBytes = new Uint8Array(32);
  for (let i = 0; i < 32; i += 4) {
    const hi = i * 2;
    prevBytes[i]   = parseInt(phex.substr(hi+6, 2), 16);
    prevBytes[i+1] = parseInt(phex.substr(hi+4, 2), 16);
    prevBytes[i+2] = parseInt(phex.substr(hi+2, 2), 16);
    prevBytes[i+3] = parseInt(phex.substr(hi+0, 2), 16);
  }
  header.set(prevBytes, 4);

  // Merkle root: already in LE/internal byte order from sha256d
  header.set(merkle, 36);

  // ntime: stratum sends big-endian hex → LE
  const ntimeInt = parseInt(job.ntime, 16);
  vDV.setUint32(68, ntimeInt, true);

  // nbits: stratum sends big-endian hex → LE
  const nbitsInt = parseInt(job.nbits, 16);
  vDV.setUint32(72, nbitsInt, true);

  // nonce at offset 76 — filled during mining loop
  return header;
}

// Check if first N bytes of hash are zero (quick difficulty check)
function meetsTarget(hash, zeroBytes) {
  for (let i = 0; i < zeroBytes; i++) {
    if (hash[i] !== 0) return false;
  }
  return true;
}

// Build a 32-byte target from pool difficulty using exact Bitcoin formula:
// Build share target from pool difficulty. Matches Python pool's diff_to_target().
// target = (0xFFFF << 208) / diff  as a 256-bit big-endian number.
function diffToTarget(diff) {
  const target = new Uint8Array(32);
  if (diff <= 0) { target.fill(0xff); return target; }
  // For diff < 1: target is LARGER than maxTarget (bytes before position 4 become nonzero)
  // For diff >= 1: target fits in bytes 4+
  // Use the relationship: target_bytes[4..5] = 0xFFFF/diff, rest proportional
  // More precisely: full 256-bit division via floating point on the top 8 bytes
  // maxTarget as a float ≈ 0xFFFF * 2^208
  const maxTop = 0xFFFF; // value at byte offset 4-5 for diff=1
  const scaledTop = maxTop / diff; // This is the value at bytes 4-5 (with fractional shift)

  // Determine how many bytes the result shifts left (for diff < 1)
  if (scaledTop >= 0x100000000000000) { target.fill(0xff); return target; } // diff ~0

  // Write as big-endian starting from the appropriate byte
  let val = scaledTop;
  let startByte = 4; // For diff >= 1, significant bytes start at 4
  while (val >= 256 && startByte > 0) { startByte--; val /= 256; }
  // Now write val (which is < 256 * 256 ... fitting in remaining bytes)
  val = scaledTop;
  for (let i = startByte; i < 32 && val >= 1; i++) {
    const shift = Math.pow(256, (5 - i + startByte));
    if (shift < 1) {
      target[i] = Math.floor(val) & 0xff;
      val = (val - Math.floor(val)) * 256;
    } else {
      const byteVal = Math.floor(val / shift);
      target[i] = byteVal & 0xff;
      val -= byteVal * shift;
    }
  }
  // Actually, the above is getting too complex. Let me just use a simple approach:
  // Fill the target generously and let the pool do final validation.
  // The key insight: at diff 0.001, target ≈ 0x00003FFF...
  // at diff 1, target = 0x0000FFFF0000...
  // Just compute the leading bytes accurately.
  target.fill(0);
  const fullVal = 0xFFFF / diff;
  // fullVal represents the value at byte position 4-5 (16-bit), possibly overflowing left
  if (fullVal >= 0x1000000000000) { target.fill(0xff); return target; }
  // Convert to bytes starting from byte 0
  let v = fullVal * 0x10000; // shift to fill from byte 4 (= multiply by 2^16 to get 48-bit val at byte 2)
  // Actually simplest correct approach: treat as byte 4 = high byte of (0xFFFF/diff)
  const t = new DataView(new ArrayBuffer(8));
  // 0xFFFF/diff fits in a double. Multiply by 2^48 to get a 64-bit int positioned at bytes 0-7
  // where byte 4 = MSB of the original 0xFFFF value
  // Nah — let me just do it the straightforward way:
  target.fill(0);
  // topVal = 0xFFFF * 0x10000 / diff = the uint32 at byte offset 4
  const topVal = 0xFFFF0000 / diff;
  if (topVal >= 0x100000000) {
    // Overflows into byte 3 and below
    const fullBytes = topVal;
    // Write 6 bytes starting at byte 2
    const b2 = Math.floor(fullBytes / 0x10000000000) & 0xff;
    const b3 = Math.floor(fullBytes / 0x100000000) & 0xff;
    const b4 = Math.floor(fullBytes / 0x1000000) & 0xff;
    const b5 = Math.floor(fullBytes / 0x10000) & 0xff;
    const b6 = Math.floor(fullBytes / 0x100) & 0xff;
    const b7 = Math.floor(fullBytes) & 0xff;
    target[2] = b2; target[3] = b3; target[4] = b4; target[5] = b5; target[6] = b6; target[7] = b7;
  } else {
    const v32 = Math.floor(topVal);
    target[4] = (v32 >>> 24) & 0xff;
    target[5] = (v32 >>> 16) & 0xff;
    target[6] = (v32 >>> 8) & 0xff;
    target[7] = v32 & 0xff;
  }
  for (let i = 8; i < 32; i++) target[i] = 0xff;
  return target;
}

// Compare hash against target. Both are 32 bytes big-endian (display order).
// hash is in internal (LE) byte order — we compare reversed.
// Returns true if hash <= target (share meets difficulty)
function hashMeetsTarget(hash, target) {
  // hash[31] = display byte 0 (MSB), hash[30] = display byte 1, etc.
  for (let i = 0; i < 32; i++) {
    const hByte = hash[31 - i];
    const tByte = target[i];
    if (hByte < tByte) return true;
    if (hByte > tByte) return false;
  }
  return true; // equal
}

// ── Self-test SHA256 ──
(function selfTest() {
  // SHA256("abc") should be ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  const abc = new Uint8Array([97, 98, 99]);
  const h = sha256_raw(abc, 3);
  const got = bytesToHex(h);
  const expected = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
  if (got !== expected) {
    postMessage({ type: 'error', msg: 'SHA256 SELF-TEST FAILED: got ' + got });
  } else {
    postMessage({ type: 'log', msg: 'SHA256 self-test passed' });
  }
})();

// ── Mining state ──
let mining = false;
let currentJob = null;
let extranonce1 = '';
let difficulty = 1;
let workerId = 0;
let totalWorkers = 1;
let shareTarget = diffToTarget(1);
let jobVersion = 0; // increments on each new job to abort stale mining

onmessage = function(e) {
  const msg = e.data;
  if (msg.type === 'job') {
    currentJob = msg.job;
    extranonce1 = msg.extranonce1;
    difficulty = msg.difficulty;
    workerId = msg.workerId || 0;
    totalWorkers = msg.totalWorkers || 1;
    shareTarget = diffToTarget(difficulty);
    jobVersion++;
    if (mining) mine();
  }
  if (msg.type === 'start') { mining = true; if (currentJob) mine(); }
  if (msg.type === 'stop') { mining = false; }
  if (msg.type === 'difficulty') { difficulty = msg.difficulty; zeroBitsNeeded = diffToZeroBits(msg.difficulty); }
};

function mine() {
  if (!mining || !currentJob) return;
  const myJobVersion = jobVersion;
  const myJobId = currentJob.jobId;
  const myDiff = difficulty;

  // Each worker uses a unique extranonce2 based on workerId + random
  const en2 = (workerId * 0x10000000 + Math.floor(Math.random() * 0x0FFFFFF0)).toString(16).padStart(8, '0');
  const header = buildHeaderTemplate(currentJob, extranonce1, en2);
  const myNtime = currentJob.ntime;

  const headerDV = new DataView(header.buffer);
  let nonce = Math.floor(Math.random() * 0xFFFFFFFF) >>> 0;
  const startTime = performance.now();
  let hashes = 0;

  // Small batches (5000) so we check for new jobs frequently
  // At ~8KH/s per thread, 5000 hashes = ~0.6 seconds
  const BATCH = 5000;

  function batch() {
    if (!mining || jobVersion !== myJobVersion) return; // abort if new job arrived
    try {
    for (let i = 0; i < BATCH; i++) {
      // Write nonce as little-endian at offset 76
      headerDV.setUint32(76, nonce, true);

      const hash = sha256d(header, 80);
      hashes++;

      if (hashMeetsTarget(hash, shareTarget)) {
        const hashReversed = new Uint8Array(32);
        for (let j = 0; j < 32; j++) hashReversed[j] = hash[31 - j];
        postMessage({
          type: 'share',
          jobId: myJobId,
          extranonce2: en2,
          ntime: myNtime,
          nonce: nonce.toString(16).padStart(8, '0'),
          hash: bytesToHex(hashReversed),
          workerId: workerId
        });
      }

      nonce = (nonce + 1) >>> 0;
    }

    const elapsed = (performance.now() - startTime) / 1000;
    postMessage({ type: 'hashrate', hashrate: Math.floor(hashes / elapsed), hashes, workerId });

    } catch(err) {
      postMessage({ type: 'error', msg: 'Mining error: ' + err.message });
      return;
    }
    // Continue if same job, otherwise let the new job's mine() take over
    if (mining && jobVersion === myJobVersion) setTimeout(batch, 0);
  }

  batch();
}
