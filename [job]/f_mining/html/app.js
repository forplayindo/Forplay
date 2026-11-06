const $ = (id) => document.getElementById(id);
const panel = $('panel');
let view = null;          // 'caves' | 'wadah'
let W = null;             // payload wadah dari server
let busy = false;

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const icon = (id) => `<svg class="ic"><use href="#${id}"/></svg>`;
const mmss = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({ ok: false, msg: 'Server tidak merespons.' }));
}

function showMsg(text, ok) {
    $('msg').textContent = text || '';
    $('msg').classList.toggle('ok', !!ok);
    $('msg').classList.toggle('hidden', !text);
}

function setView(v) {
    view = v;
    $('view-caves').classList.toggle('hidden', v !== 'caves');
    $('view-wadah').classList.toggle('hidden', v !== 'wadah');
    $('go').classList.toggle('hidden', v !== 'wadah');
    showMsg('');
    panel.classList.remove('hidden');
}

// ---------------- pilih gua ----------------
function renderCaves(list) {
    $('title').textContent = 'Pintu Gua';
    $('sub').textContent = 'Pilih gua untuk menambang';
    $('cave-max').textContent = list.length ? list[0].max : 6;
    $('caves').innerHTML = list.map((c, i) => {
        const full = c.count >= c.max;
        const dots = Array.from({ length: c.max }, (_, k) => `<i class="${k < c.count ? 'on' : ''}"></i>`).join('');
        return `<div class="row"><span class="sq" style="--c:${full ? '#636366' : '#f3b354'}">${icon('i-cave')}</span>
            <span class="t">${esc(c.label)}<div class="dots">${dots}</div></span>
            <span class="d">${c.count}/${c.max}</span>
            ${full ? '<span class="full">PENUH</span>' : `<button class="cap tint" data-cave="${i + 1}">Masuk</button>`}</div>`;
    }).join('');
}

$('caves').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-cave]');
    if (!b || busy) return;
    busy = true;
    b.disabled = true;
    const res = await post('enterCave', { cave: Number(b.dataset.cave) });
    busy = false;
    if (!res.ok) {
        showMsg(res.msg || 'Gagal masuk gua.');
        renderCaves(await post('refreshCaves'));
    }
});

$('refresh').addEventListener('click', async () => renderCaves(await post('refreshCaves')));

// ---------------- ambil wadah (campuran) ----------------
let amounts = {};         // bijih -> jumlah di wadah
const stock = (r) => r.tas + r.gudang;
const total = () => Object.values(amounts).reduce((a, b) => a + b, 0);

function renderWadah() {
    $('title').textContent = 'Ambil Wadah';
    $('sub').textContent = 'Boleh campur, dilebur sekaligus';
    $('w-max').textContent = W.max;

    const busyNote = W.busy ? `Tungku ${W.busy.furnace} masih melebur milikmu (sisa ${mmss(W.busy.remaining)}). Tunggu sampai selesai.` : '';
    $('busy').textContent = busyNote;
    $('busy').classList.toggle('hidden', !busyNote);

    amounts = {};
    $('ores').innerHTML = W.rows.map((r) => {
        amounts[r.item] = 0;
        const off = stock(r) === 0;
        return `<div class="row ${off ? 'off' : ''}" data-item="${esc(r.item)}">
            <span class="sq" style="--c:#8e8e93">${icon('i-box')}</span>
            <span class="t">${esc(r.label)}<small>Tas ${r.tas} · Gudang ${r.gudang}</small></span>
            <span class="stepper"><button class="circle" data-step="-1" ${off ? 'disabled' : ''}>−</button>
            <input type="number" min="0" value="0" ${off ? 'disabled' : ''}>
            <button class="circle" data-step="1" ${off ? 'disabled' : ''}>+</button></span></div>`;
    }).join('');
    fillAll();
}

// ubah satu bijih; dibatasi stok & sisa kapasitas wadah. Update di tempat (tanpa render ulang)
function setAmount(item, v) {
    const r = W.rows.find((x) => x.item === item);
    const room = W.max - (total() - amounts[item]);
    amounts[item] = Math.max(0, Math.min(stock(r), room, Math.floor(v || 0)));
    const row = document.querySelector(`#ores [data-item="${item}"]`);
    row.querySelector('input').value = amounts[item];
    row.classList.toggle('on', amounts[item] > 0);
    updateSummary();
}

function updateSummary() {
    const n = total();
    $('w-total').textContent = n;
    const outs = W.rows.filter((r) => amounts[r.item] > 0).map((r) => `${amounts[r.item]}x ${esc(r.out)}`);
    $('w-out').innerHTML = outs.length ? outs.join('<br>') : '-';
    $('w-time').textContent = n ? `± ${mmss(n * W.perBar)}` : '-';
    $('go').disabled = !n || !!W.busy || W.carrying || busy;
}

// isi penuh: bijih paling berharga dulu (emas, perak, tembaga)
function fillAll() {
    W.rows.forEach((r) => { amounts[r.item] = 0; });
    [...W.rows].reverse().forEach((r) => setAmount(r.item, stock(r)));
    updateSummary();
}

$('ores').addEventListener('click', (e) => {
    const b = e.target.closest('[data-step]');
    if (!b || b.disabled) return;
    const item = b.closest('[data-item]').dataset.item;
    setAmount(item, amounts[item] + Number(b.dataset.step));
});

$('ores').addEventListener('change', (e) => {
    if (e.target.tagName !== 'INPUT') return;
    setAmount(e.target.closest('[data-item]').dataset.item, Number(e.target.value));
});

$('all').addEventListener('click', fillAll);
$('clear').addEventListener('click', () => W.rows.forEach((r) => setAmount(r.item, 0)));

$('go').addEventListener('click', async () => {
    if (view !== 'wadah' || busy || !total()) return;
    busy = true;
    $('go').disabled = true;
    const res = await post('takeWadah', { items: amounts });
    busy = false;
    if (!res.ok) {
        showMsg(res.msg || 'Gagal mengambil wadah.');
        updateSummary();
    }
});

// ---------------- umum ----------------
function close() {
    panel.classList.add('hidden');
    view = null;
    W = null;
    post('close');
}

$('close').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && view) close(); });

window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    if (action === 'sfx') {
        const a = new Audio(`sfx/${e.data.name}.wav`);
        a.volume = e.data.volume ?? 0.5;
        a.play().catch(() => {});
    } else if (action === 'caves') {
        setView('caves');
        renderCaves(data || []);
    } else if (action === 'wadah') {
        W = data;
        setView('wadah');
        renderWadah();
    } else if (action === 'close') {
        panel.classList.add('hidden');
        view = null;
        W = null;
    }
});
