const $ = (id) => document.getElementById(id);
const panel = $('panel');
let view = null;      // 'mandor' | 'tong'
let D = null;         // data terakhir dari client
let busy = false;
let buka = null;      // index tong yang panel isinya terbuka
let pilih = { jenis: null, n: 1 };
let tick = null;

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const icon = (id) => `<svg class="ic"><use href="#${id}"/></svg>`;
const rp = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID');
const mmss = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const jenisOf = (key) => (D && D.jenis || []).find((j) => j.key === key);

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
    $('view-mandor').classList.toggle('hidden', v !== 'mandor');
    $('view-tong').classList.toggle('hidden', v !== 'tong');
    $('m-actions').classList.toggle('hidden', v !== 'mandor');
    $('h-icon').setAttribute('href', v === 'tong' ? '#i-barrel' : '#i-grape');
    showMsg('');
    panel.classList.remove('hidden');
}

function close() {
    panel.classList.add('hidden');
    view = null; buka = null;
    clearInterval(tick); tick = null;
}

// sisa waktu tong berjalan di NUI tanpa menggambar ulang daftar
function startTick() {
    clearInterval(tick);
    tick = setInterval(() => {
        if (!D || !D.tong) return;
        let berubah = false;
        D.tong.forEach((t, i) => {
            if (!t.j || t.sisa <= 0) return;
            t.sisa -= 1;
            if (t.sisa <= 0) berubah = true;
            document.querySelectorAll(`[data-sisa="${i}"]`).forEach((el) => { el.textContent = mmss(Math.max(0, t.sisa)); });
            document.querySelectorAll(`[data-bar="${i}"]`).forEach((el) => {
                el.style.setProperty('--v', `${100 - (t.sisa / ((D.fermentasiMenit || 15) * 60)) * 100}%`);
            });
        });
        if (berubah) view === 'tong' ? renderTong() : renderMandor();
    }, 1000);
}

// ---------------- MANDOR ----------------
function tongRingkas(t) {
    if (!t.j) return '<span class="d">Kosong</span>';
    const j = jenisOf(t.j);
    if (t.sisa <= 0) return `<span class="ok">${esc(j ? j.label : t.j)} siap</span>`;
    return `<span class="d">${esc(j ? j.label : t.j)} · <span data-sisa="${D.tong.indexOf(t)}">${mmss(t.sisa)}</span></span>`;
}

function renderMandor() {
    $('title').textContent = 'Mandor Kebun';
    $('sub').textContent = 'Kebun Anggur Marlowe';

    const st = $('m-status');
    if (D.kerja) {
        st.textContent = D.pegang ? 'Sedang bekerja · masih memegang anggur di tangan' : `Sedang bekerja · keranjang ${D.isi}/${D.max}`;
        st.className = 'notice';
    } else {
        st.textContent = 'Siapa saja boleh bekerja di sini. Baju kerja dan keranjang disiapkan Mandor.';
        st.className = 'notice';
    }
    $('m-baju').classList.toggle('hidden', !(D.kerja && !D.baju));

    $('m-blok').innerHTML = D.jenis.map((j) => `
        <div class="row"><span class="sq" style="--c:${j.warna}">${icon('i-grape')}</span>
            <span class="t">${esc(j.label)}<small>${esc(j.anggur)} · ${esc(j.blok)}</small></span>
            <span class="price">${rp(j.harga)}</span>
            <button class="cap tint" data-rute="${esc(j.key)}">${icon('i-pin')}Rute</button></div>`).join('');

    const s = D.stat || {};
    $('m-stat').innerHTML = [
        ['Tandan dipetik', s.t || 0], ['Botol jus dibuat', s.j || 0], ['Wine dibotolkan', s.w || 0],
    ].map(([k, v]) => `<div class="row"><span class="t">${k}</span><span class="d">${v}</span></div>`).join('');

    $('m-tong').innerHTML = D.tong.map((t, i) => `<div class="row"><span class="t">Tong ${i + 1}</span>${tongRingkas(t)}</div>`).join('');

    $('m-alur').innerHTML = `Petik <b>${D.max} tandan</b> satu jenis → injak di tong pinggir blok → 1 botol jus = 4 wine → fermentasi <b>${D.fermentasiMenit} menit</b> di tong winery → jual di Koperasi Balai Kota.`;

    const go = $('m-go');
    go.className = D.kerja ? 'pill red' : 'primary b-lg';
    go.textContent = D.kerja ? 'Selesai Kerja' : 'Mulai Kerja';
    go.dataset.confirm = '';
}

$('m-blok').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-rute]');
    if (!b) return;
    const r = await post('waypoint', { jenis: b.dataset.rute });
    if (r.ok) showMsg('Rute dipasang di peta.', true);
});

$('m-baju-btn').addEventListener('click', () => post('baju'));

$('m-go').addEventListener('click', async () => {
    if (busy || !D) return;
    const go = $('m-go');
    if (D.kerja) {
        const ada = D.isi > 0 || D.pegang;
        if (ada && !go.dataset.confirm) {
            go.dataset.confirm = '1';
            go.textContent = 'Yakin? Anggur di keranjang hilang';
            showMsg(`Keranjangmu masih berisi ${D.isi} tandan. Kalau selesai sekarang, anggurnya hilang.`);
            return;
        }
        busy = true;
        await post('selesai');
        busy = false;
        return;
    }
    busy = true;
    go.disabled = true;
    const r = await post('mulai');
    busy = false;
    go.disabled = false;
    if (!r.ok) showMsg(r.msg || 'Gagal mulai kerja.');
});

// ---------------- TONG ----------------
function renderTong() {
    $('title').textContent = 'Tong Fermentasi';
    $('sub').textContent = `Fermentasi ${D.fermentasiMenit || 15} menit · 1 botol jus = ${D.botolPerJus} wine`;

    $('t-jus').innerHTML = D.jenis.map((j) => {
        const n = (D.jus || {})[j.key] || 0;
        return `<div class="chip ${n ? '' : 'off'}"><span class="dot" style="--c:${j.warna}"></span>${esc(j.label.replace('Wine ', ''))}<b>${n}</b></div>`;
    }).join('');

    $('t-list').innerHTML = D.tong.map((t, i) => {
        const j = t.j && jenisOf(t.j);
        let kanan, sub;
        if (!t.j) {
            sub = 'Kosong';
            kanan = `<button class="cap tint" data-isi="${i}">${buka === i ? 'Batal' : 'Isi'}</button>`;
        } else if (t.sisa > 0) {
            sub = `${esc(j.label)} · ${t.n} botol jus → ${t.wine} wine`;
            const v = 100 - (t.sisa / ((D.fermentasiMenit || 15) * 60)) * 100;
            kanan = `<div class="tong-run"><span class="d" data-sisa="${i}">${mmss(t.sisa)}</span><div class="bar"><i data-bar="${i}" style="--v:${v}%"></i></div></div>`;
        } else {
            sub = `${esc(j.label)} · siap dibotolkan`;
            kanan = `<button class="cap fill" data-botol="${i}">${icon('i-bottle')}Botolkan ${t.wine}</button>`;
        }
        const warna = j ? j.warna : '#636366';
        let row = `<div class="row"><span class="sq" style="--c:${warna}">${icon('i-barrel')}</span>
            <span class="t">Tong ${i + 1}<small>${sub}</small></span>${kanan}</div>`;
        if (buka === i && !t.j) row += isiPanel(i);
        return row;
    }).join('');

    $('t-info').textContent = `Satu tong untuk satu jenis jus, maksimal ${D.maxJus} botol jus. Waktu fermentasi tetap berjalan walau kamu pergi atau keluar kota.`;
}

function isiPanel(i) {
    const ada = D.jenis.filter((j) => ((D.jus || {})[j.key] || 0) > 0);
    if (!ada.length) return `<div class="fill-row"><span class="t-muted">Kamu tidak membawa botol jus. Injak anggur di tong pinggir blok kebun dulu.</span></div>`;
    if (!pilih.jenis || !ada.find((j) => j.key === pilih.jenis)) pilih = { jenis: ada[0].key, n: 1 };
    const max = Math.min(D.maxJus, D.jus[pilih.jenis] || 0);
    pilih.n = Math.max(1, Math.min(pilih.n, max));
    const seg = D.jenis.map((j) => {
        const n = (D.jus || {})[j.key] || 0;
        return `<button data-jenis="${j.key}" class="${pilih.jenis === j.key ? 'active' : ''}" ${n ? '' : 'disabled'}>${esc(j.label.replace('Wine ', ''))}</button>`;
    }).join('');
    return `<div class="fill-row">
        <div class="seg">${seg}</div>
        <div class="fill-line">
            <div class="stepper"><button class="circle" data-step="-1">−</button><b>${pilih.n}</b><button class="circle" data-step="1">+</button></div>
            <span class="t-muted">= ${pilih.n * D.botolPerJus} botol wine nanti</span>
            <button class="cap fill" data-tuang="${i}">Tuang</button>
        </div></div>`;
}

$('t-list').addEventListener('click', async (e) => {
    if (busy) return;
    const isi = e.target.closest('[data-isi]');
    const j = e.target.closest('[data-jenis]');
    const st = e.target.closest('[data-step]');
    const tu = e.target.closest('[data-tuang]');
    const bo = e.target.closest('[data-botol]');
    if (isi) { const i = Number(isi.dataset.isi); buka = buka === i ? null : i; renderTong(); return; }
    if (j) { pilih = { jenis: j.dataset.jenis, n: 1 }; renderTong(); return; }
    if (st) { pilih.n += Number(st.dataset.step); renderTong(); return; }
    if (tu || bo) {
        busy = true;
        const r = tu
            ? await post('tuang', { i: Number(tu.dataset.tuang) + 1, jenis: pilih.jenis, n: pilih.n })
            : await post('botolkan', { i: Number(bo.dataset.botol) + 1 });
        busy = false;
        if (r.ok) {
            D.tong = r.tong; D.jus = r.jus; buka = null;
            renderTong();
            showMsg(tu ? 'Jus dituang. Fermentasi dimulai.' : `${r.jumlah} botol ${r.label} masuk ke tasmu.`, true);
        } else {
            showMsg(r.msg || 'Gagal. Coba lagi.');
            const f = await post('refreshTong');
            if (f && f.tong) { D.tong = f.tong; D.jus = f.jus; renderTong(); }
        }
    }
});

// ---------------- HUD injak ----------------
let flashT = null;
function injak(m) {
    const hud = $('injak');
    if (m.show === false) { hud.classList.add('hidden'); return; }
    if (m.show) hud.classList.remove('hidden');
    if (m.warna) hud.style.setProperty('--jus', m.warna);
    if (m.key) $('k-now').textContent = m.key;
    if (m.next) $('k-next').textContent = m.next;
    if (m.progress !== undefined) $('k-bar').style.width = `${Math.round(m.progress * 100)}%`;
    $('k-hint').textContent = m.tunggu ? 'Hampir selesai, terus injak...' : 'Tekan tombol yang menyala';
    if (m.flash) {
        const k = $('k-now');
        k.classList.remove('ok', 'bad');
        void k.offsetWidth;
        k.classList.add(m.flash);
        clearTimeout(flashT);
        flashT = setTimeout(() => k.classList.remove('ok', 'bad'), 160);
    }
}

// ---------------- pesan dari client ----------------
window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'mandor') { D = m.data; buka = null; setView('mandor'); renderMandor(); startTick(); }
    else if (m.action === 'tong') { D = m.data; buka = null; setView('tong'); renderTong(); startTick(); }
    else if (m.action === 'tutup') close();
    else if (m.action === 'injak') injak(m);
});

$('close').addEventListener('click', () => post('tutup'));
document.addEventListener('keyup', (e) => { if (e.key === 'Escape' && view) post('tutup'); });
