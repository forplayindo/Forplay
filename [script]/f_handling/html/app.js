// f_handling NUI
const $ = (s) => document.querySelector(s);
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_handling';

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
}

const KIND = { live: 'Langsung', spawn: 'Spawn ulang', restart: 'Setelah restart' };

let GROUPS = [], FIELD = {};
let cars = [], byKey = {};
let sel = null, tab = 0;
let edits = {};            // [key] = { field: angka } belum disimpan
let vehicle = { key: null, driver: false };
let busy = false;

const decOf = (step) => (step >= 1 ? 0 : (String(step).split('.')[1] || '').length);
const fmt = (v, step) => (v == null ? '-' : Number(v).toLocaleString('id-ID', { minimumFractionDigits: decOf(step), maximumFractionDigits: decOf(step) }));
const fmtIn = (v, step) => (v == null ? '' : Number(v).toFixed(decOf(step)).replace('.', ','));
const same = (a, b) => a != null && b != null && Math.abs(a - b) < 1e-6;
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

const car = () => byKey[sel];
const valOf = (k) => (edits[sel] && edits[sel][k] != null ? edits[sel][k] : car().cur[k]);
const editCount = (key) => Object.keys(edits[key] || {}).length;

function toast(text, bad) {
    const el = $('#toast');
    el.textContent = text;
    el.classList.toggle('bad', !!bad);
    el.classList.add('show');
    clearTimeout(toast.h);
    toast.h = setTimeout(() => el.classList.remove('show'), 3200);
}

// ---------- render ----------
function renderList() {
    const q = $('#q').value.trim().toLowerCase();
    $('#vlist').innerHTML = cars.filter((c) => !q || (c.name + ' ' + c.models.join(' ') + ' ' + c.res).toLowerCase().includes(q)).map((c) => `
        <button class="veh ${c.key === sel ? 'on' : ''}" data-key="${esc(c.key)}">
            <span class="vi"><svg class="ic"><use href="#i-car"/></svg></span>
            <span class="t"><b>${esc(c.name)}</b><small>${esc(c.models.join(', ') || 'model tidak ditemukan')}</small></span>
            ${vehicle.key === c.key ? '<svg class="ic drv"><use href="#i-wheel"/></svg>' : ''}
            ${editCount(c.key) ? '<span class="dot" title="Ada perubahan belum disimpan"></span>' : ''}
        </button>`).join('') || '<div class="empty">Tidak ada yang cocok</div>';
}

function renderHead() {
    const c = car();
    $('#vname').textContent = c.name;
    $('#vchips').innerHTML = `
        <span class="chip mono">${esc(c.res)}/${esc(c.path)}</span>
        <span class="chip mono">model: ${esc(c.models.join(', ') || '-')}</span>
        ${c.by ? `<span class="chip accent">Terakhir: ${esc(c.by)} · ${esc(c.at)}</span>` : ''}`;
    renderBanner();
}

function renderBanner() {
    const c = car(), b = $('#vbanner');
    if (vehicle.key === sel && vehicle.driver) {
        b.className = 'banner ok';
        b.innerHTML = '<span>Kamu sedang mengemudikan mobil ini. Geser slider = langsung terasa (hanya untukmu sampai disimpan).</span>';
    } else {
        b.className = 'banner warn';
        b.innerHTML = `<span>${vehicle.key === sel ? 'Duduk di kursi sopir' : `Naik ${esc(c.name)}`} untuk mencoba langsung. Tanpa itu, perubahan tetap bisa disimpan.</span>
            ${c.models.length ? '<button class="b b-sm b-tinted" id="spawn"><svg class="ic"><use href="#i-spawn"/></svg>Spawn untuk tes</button>' : ''}`;
    }
}

function delta(el, now, base, invert) {
    if (now == null || base == null || same(now, base) || !base) { el.textContent = 'bawaan'; el.className = ''; return; }
    const pct = Math.round(((now - base) / Math.abs(base)) * 100);
    el.textContent = `${pct > 0 ? '+' : ''}${pct}% dari bawaan`;
    el.className = (now > base) !== !!invert ? 'up' : 'down';
}

function renderStats() {
    const c = car();
    const top = valOf('fInitialDriveMaxFlatVel'), force = valOf('fInitialDriveForce'), mass = valOf('fMass'), grip = valOf('fTractionCurveMax');
    const pw = force && mass ? (force / mass) * 100000 : null;
    const pwo = c.orig.fInitialDriveForce && c.orig.fMass ? (c.orig.fInitialDriveForce / c.orig.fMass) * 100000 : null;
    $('#s-top').innerHTML = `${fmt(top, 1)}<small>km/j</small>`;
    $('#s-pw').textContent = pw == null ? '-' : pw.toLocaleString('id-ID', { maximumFractionDigits: 1 });
    $('#s-grip').textContent = fmt(grip, 0.01);
    $('#s-mass').innerHTML = `${fmt(mass, 1)}<small>kg</small>`;
    delta($('#d-top'), top, c.orig.fInitialDriveMaxFlatVel);
    delta($('#d-pw'), pw, pwo);
    delta($('#d-grip'), grip, c.orig.fTractionCurveMax);
    delta($('#d-mass'), mass, c.orig.fMass, true);
    $('#b-top').style.width = `${Math.min(100, ((top || 0) / 300) * 100)}%`;
    $('#b-pw').style.width = `${Math.min(100, ((pw || 0) / 30) * 100)}%`;
    $('#b-grip').style.width = `${Math.min(100, ((grip || 0) / 4) * 100)}%`;
    $('#b-mass').style.width = `${Math.min(100, ((mass || 0) / 30000) * 100)}%`;
}

function renderTabs() {
    $('#tabs').innerHTML = GROUPS.map((g, i) => {
        const n = g.fields.filter((f) => edits[sel] && edits[sel][f.key] != null).length;
        return `<button class="${i === tab ? 'active' : ''}" data-tab="${i}">${esc(g.label)}${n ? `<span class="cnt">${n}</span>` : ''}</button>`;
    }).join('');
}

function rowBadges(f) {
    const c = car(), v = valOf(f.key);
    let s = `<span class="kb ${f.kind}">${KIND[f.kind]}</span>`;
    if (edits[sel] && edits[sel][f.key] != null) s += '<span class="kb ch">Belum disimpan</span>';
    else if (!same(c.cur[f.key], c.orig[f.key])) s += '<span class="kb mod">Sudah diubah</span>';
    return s;
}

function renderFields() {
    const c = car(), g = GROUPS[tab];
    $('#fields').innerHTML = `<div class="group">${g.fields.map((f) => {
        const v = valOf(f.key), missing = c.cur[f.key] == null;
        return `<div class="row" data-k="${f.key}">
            <div class="lbl"><div class="a">${esc(f.label)} <span class="badges">${rowBadges(f)}</span></div>
                <div class="f">${f.key}${missing ? ' · tidak ada di file, akan ditambahkan' : ''}</div><div class="h">${esc(f.hint)}</div></div>
            <div class="sl"><input type="range" min="${f.min}" max="${f.max}" step="${f.step}" value="${v ?? f.min}">
                <div class="rng"><span>${fmt(f.min, f.step)}</span><span>bawaan ${fmt(c.orig[f.key], f.step)}</span><span>${fmt(f.max, f.step)}</span></div></div>
            <div class="val"><input type="text" class="${edits[sel] && edits[sel][f.key] != null ? 'changed' : ''}" value="${fmtIn(v, f.step)}">
                <button data-orig="${f.key}">↺ bawaan</button></div>
        </div>`;
    }).join('')}</div>`;
}

function renderFoot() {
    const n = editCount(sel);
    const c = car();
    const drv = vehicle.key === sel && vehicle.driver;
    $('#finfo').textContent = n
        ? `${n} nilai belum disimpan${drv ? ' · sudah terasa di mobilmu' : ''}. Simpan = tulis ke ${c.path} + langsung dipakai semua pemain.`
        : 'Belum ada perubahan.';
    $('#save').disabled = !n || busy;
    $('#cancel').disabled = !n;
}

function renderAll() {
    renderList(); renderHead(); renderStats(); renderTabs(); renderFields(); renderFoot();
}

// update satu baris tanpa render ulang (slider & scroll tidak loncat)
function updateRow(k) {
    const row = document.querySelector(`.row[data-k="${k}"]`);
    if (!row) return;
    const f = FIELD[k], v = valOf(k);
    row.querySelector('input[type=range]').value = v;
    const inp = row.querySelector('.val input');
    if (document.activeElement !== inp) inp.value = fmtIn(v, f.step);
    inp.classList.toggle('changed', !!(edits[sel] && edits[sel][k] != null));
    row.querySelector('.badges').innerHTML = rowBadges(f);
}

// ---------- edit ----------
const pending = {};
let flushTimer = null;
function queuePreview(k, v) {
    pending[k] = v;
    if (flushTimer) return;
    flushTimer = setTimeout(() => {
        flushTimer = null;
        const values = { ...pending };
        for (const key in pending) delete pending[key];
        post('preview', { key: sel, values });
    }, 70);
}

function setVal(k, v) {
    const f = FIELD[k];
    if (v == null || isNaN(v)) return;
    v = Math.min(f.max, Math.max(f.min, v));
    v = Number((Math.round(v / f.step) * f.step).toFixed(decOf(f.step)));
    const c = car();
    edits[sel] = edits[sel] || {};
    if (same(v, c.cur[k])) delete edits[sel][k]; else edits[sel][k] = v;
    if (!Object.keys(edits[sel]).length) delete edits[sel];
    updateRow(k);
    renderStats(); renderTabs(); renderFoot(); renderList();
    queuePreview(k, v);
}

function selectCar(key) {
    if (key === sel || !byKey[key]) return;
    if (sel && edits[sel]) post('revert', { key: sel }); // percobaan mobil lama dikembalikan, editan tetap diingat
    sel = key;
    renderAll();
    if (edits[sel]) post('preview', { key: sel, values: edits[sel] });
}

// ---------- event ----------
$('#vlist').addEventListener('click', (e) => { const b = e.target.closest('.veh'); if (b) selectCar(b.dataset.key); });
$('#q').addEventListener('input', renderList);
$('#tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-tab]');
    if (!b) return;
    tab = +b.dataset.tab;
    renderTabs(); renderFields();
    $('#fields').scrollTop = 0;
});
$('#fields').addEventListener('input', (e) => {
    if (e.target.type !== 'range') return;
    setVal(e.target.closest('.row').dataset.k, parseFloat(e.target.value));
});
$('#fields').addEventListener('change', (e) => {
    if (e.target.type !== 'text') return;
    const k = e.target.closest('.row').dataset.k;
    setVal(k, parseFloat(e.target.value.replace(/\s/g, '').replace(',', '.')));
    e.target.value = fmtIn(valOf(k), FIELD[k].step);
});
$('#fields').addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target.type === 'text') e.target.blur(); });
$('#fields').addEventListener('click', (e) => { const k = e.target.dataset && e.target.dataset.orig; if (k) setVal(k, car().orig[k]); });

$('#vbanner').addEventListener('click', async (e) => {
    if (!e.target.closest('#spawn')) return;
    const r = await post('spawn', { key: sel });
    if (r && r.ok === false) toast(r.msg, true);
});

$('#cancel').onclick = () => {
    if (!edits[sel]) return;
    delete edits[sel];
    post('revert', { key: sel });
    renderAll();
    toast('Perubahan dibatalkan, kembali ke nilai tersimpan.');
};

$('#orig').onclick = () => {
    const c = car();
    let n = 0;
    for (const g of GROUPS) for (const f of g.fields) {
        if (c.orig[f.key] != null && !same(valOf(f.key), c.orig[f.key])) { setVal(f.key, c.orig[f.key]); n++; }
    }
    toast(n ? `${n} nilai diisi kembali ke bawaan (saat server dinyalakan). Tekan Simpan untuk menerapkan.` : 'Semua nilai sudah sama dengan bawaan.');
};

$('#save').onclick = async () => {
    if (!edits[sel] || busy) return;
    busy = true; renderFoot();
    const key = sel;
    const r = await post('save', { key, values: edits[key] });
    busy = false;
    if (r && r.ok) {
        byKey[key] = r.car;
        cars = cars.map((c) => (c.key === key ? r.car : c));
        delete edits[key];
        toast(r.msg);
    } else {
        toast((r && r.msg) || 'Gagal menyimpan.', true);
    }
    if (key === sel) renderAll(); else renderList();
};

$('#export').onclick = async () => {
    const r = await post('file', { key: sel });
    if (!r || !r.ok) return toast((r && r.msg) || 'Gagal membaca file.', true);
    $('#m-title').textContent = r.path;
    $('#m-text').value = r.text;
    $('#modal').classList.remove('hidden');
    $('#m-text').scrollTop = 0;
};
$('#m-close').onclick = () => $('#modal').classList.add('hidden');
$('#m-copy').onclick = () => {
    const t = $('#m-text');
    t.focus(); t.select();
    try { document.execCommand('copy'); toast('Isi file disalin. Tempel ke handling.meta lokal kalau perlu.'); } catch { toast('Tekan Ctrl+C untuk menyalin.'); }
};

$('#drive').onclick = () => {
    $('#panel').classList.add('driving');
    $('#drive-hint').classList.remove('hidden');
    post('drive');
};
$('#close').onclick = () => post('close');

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || $('#panel').classList.contains('hidden')) return;
    if (!$('#modal').classList.contains('hidden')) { $('#modal').classList.add('hidden'); return; }
    post('close');
});

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') {
        GROUPS = d.groups || [];
        FIELD = {};
        for (const g of GROUPS) for (const f of g.fields) FIELD[f.key] = f;
        cars = d.cars || [];
        byKey = {};
        for (const c of cars) byKey[c.key] = c;
        vehicle = d.vehicle || { key: null, driver: false };
        edits = {};
        sel = (vehicle.key && byKey[vehicle.key]) ? vehicle.key : (byKey[sel] ? sel : cars[0].key);
        tab = Math.min(tab, GROUPS.length - 1);
        $('#q').value = '';
        $('#panel').classList.remove('hidden', 'driving');
        $('#drive-hint').classList.add('hidden');
        $('#modal').classList.add('hidden');
        renderAll();
    } else if (d.action === 'close') {
        $('#panel').classList.add('hidden');
        $('#modal').classList.add('hidden');
        edits = {};
    } else if (d.action === 'focus') {
        $('#panel').classList.remove('driving');
        $('#drive-hint').classList.add('hidden');
    } else if (d.action === 'vehicle') {
        vehicle = d.vehicle || { key: null, driver: false };
        if (!sel) return;
        renderList(); renderBanner(); renderFoot();
        // mobil baru (mis. habis spawn): pasang lagi percobaan yang belum disimpan
        if (vehicle.key && vehicle.key === sel && edits[sel]) post('preview', { key: sel, values: edits[sel] });
    }
});
