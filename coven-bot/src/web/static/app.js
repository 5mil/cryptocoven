// app.js -- Crypto Coven Dashboard
// Polls /api/* every 15s, renders miners, alerts, blocks, sparklines

const POLL_MS       = 15_000;
const SPARKLINE_PTS = 30;
const sparkData     = {};

document.addEventListener('DOMContentLoaded', () => {
  fetchAll();
  setInterval(fetchAll, POLL_MS);
});

async function fetchAll() {
  try {
    const [party, miners, blocks, alerts] = await Promise.all([
      apiFetch('/api/party'),
      apiFetch('/api/miners'),
      apiFetch('/api/blocks'),
      apiFetch('/api/alerts'),
    ]);
    renderParty(party);
    renderMiners(miners);
    renderBlocks(blocks);
    renderAlerts(alerts);
    renderSparklines(miners);
    setStatus(true);
    document.getElementById('last-update').textContent =
      'Updated ' + new Date().toLocaleTimeString();
  } catch (e) {
    console.error('Fetch error:', e);
    setStatus(false);
  }
}

async function apiFetch(url) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`${url} -> ${r.status}`);
  return r.json();
}

// -- Party cards --------------------------------------------------------------
function renderParty(p) {
  setText('total-hashrate', p.total_hashrate != null ? fmtHash(p.total_hashrate) : '--');
  setText('active-miners',  p.active_miners  ?? '--');
  setText('blocks-found',   p.blocks_found   ?? '--');
  setText('est-earnings',   p.estimated_earnings != null
    ? p.estimated_earnings.toFixed(6) + ' coins' : '--');
}

// -- Miners table -------------------------------------------------------------
function renderMiners(miners) {
  const tbody = document.getElementById('miners-body');
  setText('miner-count', miners.length);
  if (!miners.length) {
    tbody.innerHTML = '<tr><td colspan="9" class="empty">No active miners</td></tr>';
    return;
  }
  tbody.innerHTML = miners.map(m => `
    <tr>
      <td><code>${esc(m.worker_name)}</code></td>
      <td>${esc(m.username)}</td>
      <td><span class="pill" style="background:#1e0a3c;color:#a78bfa;border:1px solid #6d28d9">${esc(m.algorithm)}</span></td>
      <td>${regionFlag(m.region)} ${esc(m.region)}</td>
      <td style="color:var(--cyan);font-weight:600">${fmtHash(m.hashrate)}</td>
      <td style="color:var(--green)">${m.accepted.toLocaleString()}</td>
      <td style="color:${m.rejected > 0 ? 'var(--red)' : 'var(--muted)'}">${m.rejected.toLocaleString()}</td>
      <td><span class="pill ${m.is_online ? 'pill-online' : 'pill-offline'}">${m.is_online ? 'Online' : 'Offline'}</span></td>
      <td class="muted">${timeAgo(m.last_seen)}</td>
    </tr>
  `).join('');
}

// -- Alerts -------------------------------------------------------------------
function renderAlerts(alerts) {
  const list  = document.getElementById('alerts-list');
  const badge = document.getElementById('alert-count');
  badge.textContent = alerts.length;
  badge.className = alerts.length > 0 ? 'badge badge-red' : 'badge';
  if (!alerts.length) {
    list.innerHTML = '<li class="empty">No active alerts</li>';
    return;
  }
  list.innerHTML = alerts.map(a => `
    <li>
      <div>
        <div class="alert-msg sev-${a.severity}">${sevIcon(a.severity)} ${esc(a.message)}</div>
        <div class="alert-time">${timeAgo(a.created_at)}</div>
      </div>
      <button class="ack-btn" onclick="ackAlert(${a.id})">Ack</button>
    </li>
  `).join('');
}

async function ackAlert(id) {
  try {
    await fetch(`/api/alerts/${id}/ack`, { method: 'POST' });
    fetchAll();
  } catch(e) { console.error('Ack failed:', e); }
}

// -- Blocks -------------------------------------------------------------------
function renderBlocks(blocks) {
  const list = document.getElementById('blocks-list');
  if (!blocks.length) {
    list.innerHTML = '<li class="empty">No blocks found yet -- keep mining!</li>';
    return;
  }
  list.innerHTML = blocks.map(b => `
    <li>
      <div style="display:flex;justify-content:space-between;align-items:center">
        <span class="block-coin">${esc(b.coin)}</span>
        <span class="block-reward">+${b.reward.toFixed(4)}</span>
      </div>
      <div style="display:flex;justify-content:space-between;margin-top:3px">
        <span class="block-height">#${b.block_height}</span>
        <span class="block-finder">${esc(b.finder)}</span>
      </div>
      <div class="block-hash">${esc(b.block_hash.slice(0,24))}...</div>
      <div style="font-size:11px;color:var(--muted);margin-top:2px">${timeAgo(b.found_at)}</div>
    </li>
  `).join('');
}

// -- Sparklines ---------------------------------------------------------------
function renderSparklines(miners) {
  const container = document.getElementById('sparklines');
  miners.forEach(m => {
    const key = m.worker_name;
    if (!sparkData[key]) sparkData[key] = [];
    sparkData[key].push(m.hashrate);
    if (sparkData[key].length > SPARKLINE_PTS) sparkData[key].shift();
    let card = document.getElementById('spark-' + key);
    if (!card) {
      card = document.createElement('div');
      card.className = 'sparkline-card';
      card.id = 'spark-' + key;
      card.innerHTML = `<h3>${esc(key)}</h3><canvas width="200" height="50"></canvas>`;
      container.appendChild(card);
    }
    drawSparkline(card.querySelector('canvas'), sparkData[key], m.is_online);
  });
}

function drawSparkline(canvas, data, isOnline) {
  const ctx = canvas.getContext('2d');
  const W = canvas.width, H = canvas.height;
  ctx.clearRect(0, 0, W, H);
  if (data.length < 2) return;
  const max = Math.max(...data) || 1;
  const min = Math.min(...data);
  const range = max - min || 1;
  const color = isOnline ? '#22d3ee' : '#ef4444';
  ctx.beginPath();
  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.shadowColor = color;
  ctx.shadowBlur = 4;
  data.forEach((v, i) => {
    const x = (i / (data.length - 1)) * W;
    const y = H - ((v - min) / range) * (H - 8) - 4;
    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
  });
  ctx.stroke();
  ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath();
  ctx.fillStyle = color + '18';
  ctx.fill();
}

// -- Helpers ------------------------------------------------------------------
function fmtHash(h) {
  if (h >= 1e12) return (h/1e12).toFixed(2) + ' TH/s';
  if (h >= 1e9)  return (h/1e9).toFixed(2)  + ' GH/s';
  if (h >= 1e6)  return (h/1e6).toFixed(2)  + ' MH/s';
  if (h >= 1e3)  return (h/1e3).toFixed(2)  + ' KH/s';
  return h.toFixed(1) + ' H/s';
}
function timeAgo(ts) {
  if (!ts) return '--';
  const d = Math.floor(Date.now()/1000) - ts;
  if (d < 60)    return d + 's ago';
  if (d < 3600)  return Math.floor(d/60) + 'm ago';
  if (d < 86400) return Math.floor(d/3600) + 'h ago';
  return Math.floor(d/86400) + 'd ago';
}
function regionFlag(r) {
  if (!r) return '';
  const s = r.toLowerCase();
  if (s.includes('europe') || s.includes('eu')) return 'EU';
  if (s.includes('asia'))                        return 'AS';
  if (s.includes('america') || s.includes('us')) return 'NA';
  return '';
}
function sevIcon(s) { return {info:'i',warning:'!',critical:'!!'}[s]||''; }
function esc(s) {
  return String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
function setText(id, val) { const el = document.getElementById(id); if (el) el.textContent = val; }
function setStatus(ok) {
  const dot = document.getElementById('status-dot');
  if (dot) dot.className = 'dot ' + (ok ? 'dot-ok' : 'dot-err');
}
