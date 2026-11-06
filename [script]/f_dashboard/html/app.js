const $ = (id) => document.getElementById(id);
const panel = $('panel');
let D = null;              // data dari server
let page = 'ringkasan', richTab = 'total', flowRange = 'd7';
let cdTimer = null;

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n) => (n < 0 ? '-' : '') + 'Rp ' + Math.floor(Math.abs(n || 0)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const dec = (n, d = 1) => Number(n || 0).toLocaleString('id-ID', { maximumFractionDigits: d });
const short = (n) => {
    const a = Math.abs(n || 0);
    if (a >= 1e12) return 'Rp ' + dec(n / 1e12, 2) + ' T';
    if (a >= 1e9) return 'Rp ' + dec(n / 1e9, 2) + ' M';
    if (a >= 1e6) return 'Rp ' + dec(n / 1e6, 1) + ' jt';
    return fmt(n);
};
const pct = (n, d = 1) => (n > 0 ? '+' : '') + dec(n, d) + '%';
const dm = (day) => { const p = day.split('-'); return +p[2] + '/' + +p[1]; };

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => false);
}

// ===================== STATUS =====================
const STATUS = {
    lesu: '#0a84ff', sehat: '#30d158', waspada: '#ffd60a', inflasi: '#ff9f0a', kritis: '#ff453a', kumpul: '#8e8e93',
};
const ORDER = ['lesu', 'sehat', 'waspada', 'inflasi', 'kritis'];
const hexA = (hex, a) => { const n = parseInt(hex.slice(1), 16); return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`; };

const PAGES = [
    { id: 'ringkasan', label: 'Ringkasan', ic: 'i-home', sub: 'Status ekonomi 7 hari terakhir' },
    { id: 'terkaya', label: 'Terkaya', ic: 'i-crown', sub: 'Top 10 · semua karakter (online + offline)' },
    { id: 'job', label: 'Rekening Job', ic: 'i-brief', sub: 'Semua rekening job, urut saldo terbanyak' },
    { id: 'gang', label: 'Rekening Gang', ic: 'i-skull', sub: 'Semua rekening gang, urut saldo terbanyak' },
    { id: 'arus', label: 'Arus Uang', ic: 'i-flow', sub: 'Uang masuk vs keluar per kategori' },
    { id: 'sebaran', label: 'Sebaran', ic: 'i-dist', sub: 'Pembagian kekayaan pemain' },
];

function nav() {
    const st = D.status;
    $('nav').innerHTML = PAGES.map((p) => `<button class="${p.id === page ? 'active' : ''}" data-p="${p.id}"><svg class="ic"><use href="#${p.ic}"/></svg>${p.label}${p.id === 'ringkasan' && st.id !== 'kumpul' ? `<span class="bubble" style="background:${STATUS[st.id]};color:#000">${esc(st.label)}</span>` : ''}</button>`).join('');
    document.querySelectorAll('#nav button').forEach((b) => b.onclick = () => { page = b.dataset.p; render(true); });
}

function scale(value, edges) {
    const lo = edges[0] - (edges[1] - edges[0]), hi = edges[3] + (edges[3] - edges[2]);
    const pts = [lo, ...edges, hi];
    let pos = 0;
    for (let i = 0; i < 5; i++) {
        if (value <= pts[i + 1] || i === 4) { pos = (i + Math.min(1, Math.max(0, (value - pts[i]) / (pts[i + 1] - pts[i])))) / 5; break; }
    }
    const lvl = Math.min(4, Math.floor(pos * 5));
    return `<div class="scale-wrap"><div class="scale">${ORDER.map((k, i) => `<i class="${i === lvl ? 'on' : ''}" style="background:${STATUS[k]}"></i>`).join('')}</div><span class="marker" style="left:${pos * 100}%"></span></div>`;
}

function lineChart(data, color) {
    if (data.length < 2) return '<div class="empty">Grafik muncul setelah ada data 2 hari.</div>';
    const W = 600, H = 170, P = 24;
    let min = Math.min(...data.map((d) => d.v)), max = Math.max(...data.map((d) => d.v));
    if (max === min) { max += 1; min -= 1; }
    const pad = (max - min) * .08; min -= pad; max += pad;
    const x = (i) => P + i * (W - P * 2) / (data.length - 1), y = (v) => H - 22 - (v - min) / (max - min) * (H - 40);
    const pts = data.map((d, i) => `${x(i)},${y(d.v)}`).join(' ');
    const grid = [0, .5, 1].map((t) => { const v = min + (max - min) * t; return `<line x1="${P}" x2="${W - P}" y1="${y(v)}" y2="${y(v)}" stroke="rgba(84,84,88,.45)"/><text x="${W - P}" y="${y(v) - 4}" fill="rgba(235,235,245,.35)" font-size="10" text-anchor="end">${short(v)}</text>`; }).join('');
    const step = Math.max(1, Math.ceil(data.length / 6));
    const labels = data.map((d, i) => i % step === 0 || i === data.length - 1 ? `<text x="${x(i)}" y="${H - 6}" fill="rgba(235,235,245,.45)" font-size="10" text-anchor="middle">${dm(d.d)}</text>` : '').join('');
    return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">${grid}
        <polygon points="${x(0)},${H - 22} ${pts} ${x(data.length - 1)},${H - 22}" fill="${color}" opacity=".12"/>
        <polyline points="${pts}" fill="none" stroke="${color}" stroke-width="2.5" stroke-linejoin="round"/>
        <circle cx="${x(data.length - 1)}" cy="${y(data[data.length - 1].v)}" r="4" fill="${color}"/>${labels}</svg>`;
}

function barChart(data) {
    const W = 440, H = 170, P = 10;
    const max = Math.max(1, ...data.flatMap((d) => [d.i, d.o]));
    const bw = (W - P * 2) / data.length;
    return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">${data.map((d, i) => {
        const x = P + i * bw, hi = d.i / max * (H - 30), ho = d.o / max * (H - 30);
        return `<rect x="${x + bw * .14}" y="${H - 20 - hi}" width="${bw * .34}" height="${hi}" rx="2" fill="#30d158"><title>Masuk ${fmt(d.i)}</title></rect>
            <rect x="${x + bw * .52}" y="${H - 20 - ho}" width="${bw * .34}" height="${ho}" rx="2" fill="#ff453a"><title>Keluar ${fmt(d.o)}</title></rect>
            ${i % 3 === 0 || i === data.length - 1 ? `<text x="${x + bw / 2}" y="${H - 6}" fill="rgba(235,235,245,.45)" font-size="10" text-anchor="middle">${dm(d.d)}</text>` : ''}`;
    }).join('')}</svg>`;
}

// ===================== HALAMAN =====================
function pageRingkasan() {
    const st = D.status, s = D.snap, b = D.base, th = D.thresholds;
    const color = STATUS[st.id] || STATUS.kumpul;
    const flags = st.flags.length
        ? st.flags.map((f) => `<span class="chip ${f.t === 'bad' ? 'red' : 'orange'}">⚠ ${esc(f.text)}</span>`).join('')
        : '<span class="chip green">Tidak ada penanda</span>';
    const growthRow = st.growth != null
        ? `<div class="ind-row"><span>Pertumbuhan uang per pemain aktif (7 hari)</span><b>${pct(st.growth)}</b></div>${scale(st.growth, th.growth)}`
        : `<div class="ind-row"><span>Pertumbuhan uang per pemain aktif (7 hari)</span><b>${st.days}/${st.minDays} hari data</b></div>`;
    const ratioRow = st.ratio != null
        ? `<div class="ind-row"><span>Rasio uang masuk : keluar (7 hari)</span><b>${dec(st.ratio, 2)}×</b></div>${scale(st.ratio, th.ratio)}`
        : '<div class="ind-row"><span>Rasio uang masuk : keluar (7 hari)</span><b>belum ada data</b></div>';

    const mixParts = [['Bank', s.bank, '#0a84ff'], ['Cash', s.cash, '#30d158'], ['Dirty', s.dirty, '#ff453a'], ['Penyimpanan', s.storage, '#64d2ff'],
        ['Rek. Job', s.jobs, '#f3b354'], ['Rek. Gang', s.gangs, '#bf5af2'], ['Rek. Lain', s.other, '#8e8e93']].filter((p) => p[1] > 0);
    const allDelta = b && b.all > 0 ? (s.all / b.all - 1) * 100 : null;
    const medDelta = b && b.median > 0 ? (s.median / b.median - 1) * 100 : null;
    const deltaCls = (v) => v == null ? 't-muted' : v > 0 ? 't-green' : v < 0 ? 't-red' : 't-muted';

    return `
    <div class="status" style="--st:${color};--st-soft:${hexA(color, .2)};--st-line:${hexA(color, .45)}">
        <div>
            <div class="st-h"><div class="st-dot"><i></i></div><div><b>${esc(st.label)}</b><small>${esc(st.desc)}</small></div></div>
            <div class="ind">${growthRow}</div>
            <div class="ind">${ratioRow}</div>
            <div class="flags">${flags}</div>
        </div>
        <div class="rec">
            <h3><svg class="ic t-accent"><use href="#i-bulb"/></svg>Rekomendasi</h3>
            <ul>${st.rec.map((r) => `<li>${r}</li>`).join('')}</ul>
            <small>Status diambil dari indikator terburuk. Batas angka bisa diubah di config.</small>
        </div>
    </div>

    <div class="kpis">
        <div class="kpi big"><small>Total uang beredar</small><b>${short(s.all)}</b>
            <div class="delta ${allDelta != null && allDelta > 0 ? 't-orange' : 't-muted'}">${allDelta != null ? pct(allDelta) + ' dalam 7 hari' : 'belum ada pembanding 7 hari'}</div>
            <div class="mix">${mixParts.map(([, v, c]) => `<i style="flex:${v};background:${c}"></i>`).join('')}</div>
            <div class="legend">${mixParts.map(([l, v, c]) => `<span style="--c:${c}">${l} ${s.all > 0 ? dec(v / s.all * 100, 0) : 0}%</span>`).join('')}</div>
        </div>
        <div class="kpi"><small>Median per pemain</small><b>${short(s.median)}</b><div class="delta ${deltaCls(medDelta)}">${medDelta != null ? pct(medDelta) + ' (7 hari)' : '&nbsp;'}</div></div>
        <div class="kpi"><small>Rata-rata per pemain</small><b>${short(s.avg)}</b><div class="delta t-muted">${s.median > 0 ? dec(s.avg / s.median, 1) + '× median' : '&nbsp;'}</div></div>
        <div class="kpi"><small>Bank pemain</small><b>${short(s.bank)}</b></div>
        <div class="kpi"><small>Cash pemain (bersih)</small><b>${short(s.cash)}</b></div>
        <div class="kpi"><small>Dirty money pemain</small><b>${short(s.dirty)}</b></div>
        <div class="kpi"><small>Karakter dihitung</small><b>${s.players}</b><div class="delta t-muted">${s.active} aktif 7 hari${D.excluded ? ' · ' + D.excluded + ' dikecualikan' : ''}</div></div>
    </div>

    <div class="charts">
        <div class="chart"><h3>Uang beredar <small>30 hari</small></h3>${lineChart(D.series, color === STATUS.kumpul ? '#f3b354' : color)}</div>
        <div class="chart"><h3>Masuk vs keluar <small><span class="t-green">■</span> masuk · <span class="t-red">■</span> keluar · 14 hari</small></h3>${barChart(D.flow14)}</div>
    </div>
    ${s.storage > 0 ? `<small>Cash di stash/bagasi/glovebox: <b>${fmt(s.storage)}</b>${s.storageDirty > 0 ? ` (kotor ${fmt(s.storageDirty)})` : ''}, ikut dihitung di uang beredar.</small>` : ''}`;
}

function pageTerkaya() {
    const key = richTab, list = D.top[key] || [], total = key === 'total', s = D.snap;
    const all = total ? s.cash + s.bank + s.dirty : s[key];
    const cols = total ? '34px 1.6fr 1fr 1fr 1fr 1.1fr' : '34px 1.6fr 1.4fr 1fr';
    const head = total
        ? `<div class="tr th" style="grid-template-columns:${cols}"><span>#</span><span>Pemain</span><span class="r">Cash</span><span class="r">Bank</span><span class="r">Dirty</span><span class="r">Total</span></div>`
        : `<div class="tr th" style="grid-template-columns:${cols}"><span>#</span><span>Pemain</span><span>Porsi dari total ${{ bank: 'bank', cash: 'cash', dirty: 'dirty' }[key]}</span><span class="r">${{ bank: 'Bank', cash: 'Cash', dirty: 'Dirty' }[key]}</span></div>`;
    const rows = list.length ? list.map((p, i) => {
        const who = `<div class="who"><b>${esc(p.name)}${p.online ? '<span class="on-dot" title="online"></span>' : ''}</b><small>${esc(p.cid)}</small></div>`;
        const rk = `<span class="rank ${i < 3 ? 'g' + (i + 1) : ''}">${i + 1}</span>`;
        if (total) return `<div class="tr" style="grid-template-columns:${cols}">${rk}${who}<span class="r m">${short(p.cash)}</span><span class="r m">${short(p.bank)}</span><span class="r m">${short(p.dirty)}</span><span class="r"><b>${short(p.total)}</b></span></div>`;
        const share = all > 0 ? p[key] / all * 100 : 0;
        return `<div class="tr" style="grid-template-columns:${cols}">${rk}${who}<div class="share"><div class="bar"><i style="--v:${Math.min(100, share)}%"></i></div><span>${dec(share)}%</span></div><span class="r"><b>${fmt(p[key])}</b></span></div>`;
    }).join('') : '<div class="empty">Belum ada data.</div>';
    const top10 = list.reduce((a, p) => a + p[key], 0);
    return `
    <div class="seg" style="max-width:480px">${[['total', 'Total'], ['bank', 'Bank'], ['cash', 'Cash'], ['dirty', 'Dirty Money']].map(([k, l]) => `<button class="${k === key ? 'active' : ''}" data-rt="${k}">${l}</button>`).join('')}</div>
    <div class="sum-row">
        <div class="kpi"><small>Top 10 memegang</small><b>${short(top10)}</b></div>
        <div class="kpi"><small>Porsi dari semua ${total ? 'uang pemain' : key + ' pemain'}</small><b>${all > 0 ? dec(top10 / all * 100) : 0}%</b></div>
        <div class="kpi"><small>Sedang online</small><b>${list.filter((p) => p.online).length} / ${list.length}</b></div>
    </div>
    <div class="tbl">${head}${rows}</div>
    <small>Cash = uang bersih di tangan (dirty dipisah). Karakter di daftar pengecualian config tidak ditampilkan. <span class="on-dot"></span> = sedang online.</small>`;
}

function pageRekening(list, kind) {
    const sum = list.reduce((a, x) => a + x.bal, 0);
    const cols = '34px 1.5fr 1.6fr 1fr';
    return `
    <div class="sum-row">
        <div class="kpi"><small>Total saldo rekening ${kind}</small><b>${short(sum)}</b></div>
        <div class="kpi"><small>Jumlah rekening</small><b>${list.length}</b></div>
        <div class="kpi"><small>Porsi dari uang beredar</small><b>${D.snap.all > 0 ? dec(sum / D.snap.all * 100) : 0}%</b></div>
    </div>
    <div class="tbl">
        <div class="tr th" style="grid-template-columns:${cols}"><span>#</span><span>${kind === 'job' ? 'Job' : 'Gang'}</span><span>Porsi</span><span class="r">Saldo</span></div>
        ${list.length ? list.map((a, i) => {
            const share = sum > 0 ? a.bal / sum * 100 : 0;
            return `<div class="tr" style="grid-template-columns:${cols}"><span class="rank ${i < 3 ? 'g' + (i + 1) : ''}">${i + 1}</span><div class="who"><b>${esc(a.label)}</b><small>${esc(a.id)}</small></div><div class="share"><div class="bar"><i style="--v:${share}%"></i></div><span>${dec(share)}%</span></div><span class="r"><b>${fmt(a.bal)}</b></span></div>`;
        }).join('') : '<div class="empty">Belum ada rekening.</div>'}
    </div>`;
}

function pageArus() {
    const f = D.flows[flowRange];
    const block = (arr, tot, color) => arr.length ? arr.map((c) => `<div class="cat"><span>${esc(c.label)}</span><div class="bar"><i style="--v:${c.v / arr[0].v * 100}%;background:${color}"></i></div><span class="r">${short(c.v)}<small class="t-muted">${tot > 0 ? Math.round(c.v / tot * 100) : 0}%</small></span></div>`).join('') : '<div class="empty">Belum ada data.</div>';
    const unk = (arr) => arr.length ? `<div class="unk">${arr.map((u) => `<div><span>${esc(u.r)}</span><span>${short(u.v)}</span></div>`).join('')}</div>` : '<small>Tidak ada.</small>';
    const net = f.tin - f.tout;
    return `
    <div class="seg" style="max-width:360px">${[['today', 'Hari ini'], ['d7', '7 hari'], ['d30', '30 hari']].map(([k, l]) => `<button class="${k === flowRange ? 'active' : ''}" data-fr="${k}">${l}</button>`).join('')}</div>
    <div class="sum-row">
        <div class="kpi"><small>Uang masuk</small><b class="t-green">${short(f.tin)}</b></div>
        <div class="kpi"><small>Uang keluar</small><b class="t-red">${short(f.tout)}</b></div>
        <div class="kpi"><small>Selisih (uang baru)</small><b class="${net > 0 ? 't-orange' : 't-accent'}">${net > 0 ? '+' : ''}${short(net)}</b></div>
        <div class="kpi"><small>Rasio masuk : keluar</small><b>${f.tout > 0 ? dec(f.tin / f.tout, 2) + '×' : '-'}</b></div>
    </div>
    <div class="flow">
        <div class="chart"><h3>Uang masuk <small>per kategori</small></h3>${block(f.in, f.tin, '#30d158')}</div>
        <div class="chart"><h3>Uang keluar <small>per kategori</small></h3>${block(f.out, f.tout, '#ff453a')}</div>
    </div>
    <div class="flow">
        <div class="chart"><h3>Masuk "Lainnya" hari ini <small>alasan belum dikenali</small></h3>${unk(D.unknown.in)}</div>
        <div class="chart"><h3>Keluar "Lainnya" hari ini <small>alasan belum dikenali</small></h3>${unk(D.unknown.out)}</div>
    </div>
    <small>Kategori ditebak dari alasan transaksi memakai kata kunci di config (Config.Categories). Setor/tarik bank, transfer, bayar ke rekening job, dan cash yang dipindah antar inventory tidak dihitung karena tidak menambah/mengurangi uang beredar.</small>`;
}

function pageSebaran() {
    const d = D.dist, br = d.brackets, max = Math.max(1, ...br.map((b) => b.n)), tot = br.reduce((a, b) => a + b.n, 0);
    const lbl = (b) => b.hi == null ? '> ' + short(b.lo).replace('Rp ', '') : b.lo === 0 ? '< ' + short(b.hi).replace('Rp ', '') : short(b.lo).replace('Rp ', '') + ' – ' + short(b.hi).replace('Rp ', '');
    return `
    <div class="sum-row">
        <div class="kpi"><small>10% terkaya menguasai</small><b class="${d.top10 > D.inequality ? 't-orange' : ''}">${dec(d.top10, 0)}%</b><div class="delta t-muted">batas ketimpangan: ${D.inequality}%</div></div>
        <div class="kpi"><small>50% termiskin menguasai</small><b>${dec(d.bottom50)}%</b></div>
        <div class="kpi"><small>Median</small><b>${short(d.median)}</b></div>
        <div class="kpi"><small>Indeks Gini</small><b>${dec(d.gini, 2)}</b><div class="delta t-muted">0 = merata · 1 = timpang</div></div>
    </div>
    <div class="chart"><h3>Jumlah pemain per rentang kekayaan <small>cash + bank (termasuk dirty) · ${tot} karakter</small></h3>
        <div class="hist">${br.map((b) => `<div class="col"><b>${b.n}</b><i style="height:${b.n / max * 100}%"></i><small>${lbl(b)}</small></div>`).join('')}</div>
    </div>`;
}

// ===================== RENDER =====================
function stamp() {
    const t = new Date(D.updated * 1000);
    $('stamp').innerHTML = `Data per <b class="t-accent">${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')}</b><br>Update otomatis tiap ${D.every} menit`;
}

function render(top) {
    nav();
    const p = PAGES.find((x) => x.id === page);
    $('title').textContent = p.label;
    $('sub').textContent = p.sub;
    const el = $('page');
    const scroll = el.scrollTop;
    el.innerHTML = page === 'ringkasan' ? pageRingkasan()
        : page === 'terkaya' ? pageTerkaya()
        : page === 'job' ? pageRekening(D.jobs, 'job')
        : page === 'gang' ? pageRekening(D.gangs, 'gang')
        : page === 'arus' ? pageArus() : pageSebaran();
    el.scrollTop = top ? 0 : scroll;
    el.querySelectorAll('[data-rt]').forEach((b) => b.onclick = () => { richTab = b.dataset.rt; render(); });
    el.querySelectorAll('[data-fr]').forEach((b) => b.onclick = () => { flowRange = b.dataset.fr; render(); });
    stamp();
}

function countdown(seconds) {
    const b = $('refresh');
    clearInterval(cdTimer);
    let left = Math.ceil(seconds);
    const tick = () => {
        if (left <= 0) {
            clearInterval(cdTimer);
            b.disabled = false;
            b.innerHTML = '<svg class="ic"><use href="#i-refresh"/></svg> Refresh';
            return;
        }
        b.disabled = true;
        b.textContent = `Tunggu ${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
        left -= 1;
    };
    tick();
    cdTimer = setInterval(tick, 1000);
}

$('refresh').onclick = async () => {
    const b = $('refresh');
    if (b.disabled) return;
    b.disabled = true;
    b.textContent = 'Menghitung…';
    const res = await post('refresh');
    if (res && res.data) {
        D = res.data;
        render();
        countdown(D.cooldown);
    } else {
        countdown(res && res.wait ? res.wait : 10);
    }
};

function close() {
    panel.classList.add('hidden');
    clearInterval(cdTimer);
    post('close');
}
$('close').onclick = close;
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !panel.classList.contains('hidden')) close(); });

window.addEventListener('message', (e) => {
    const m = e.data;
    if (m.action === 'open') {
        D = m.data;
        panel.classList.remove('hidden');
        render(true);
        countdown(D.lastBuild + D.cooldown - D.now);
    }
});
