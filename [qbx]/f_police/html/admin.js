// Panel Administrasi (tilang). Server yang memutuskan semuanya; panel ini hanya memilih dan mengirim.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_police';
    const root = document.getElementById('admin');
    const $ = (id) => document.getElementById(id);
    const arr = (v) => (Array.isArray(v) ? v : Object.values(v || {}));
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID');
    const post = (name, data = {}) =>
        fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
            .then((r) => r.json())
            .catch(() => null);

    let D = null;        // data dari server
    let action = null;   // 'fine' | 'sim' | 'stnk' | 'seize'
    let picked = [];     // pilihan di lembar form
    let busy = false;

    const NO_PLAYER = 'Tidak ada orang di dekatmu';

    function cards() {
        const t = D.target;
        const v = D.vehicle;
        return [
            { key: 'fine', icon: '🧾', title: 'Denda', sub: 'Tagihan dikirim ke HP, dibayar lewat Bank', price: 'Pilih pelanggaran',
              off: !t && NO_PLAYER },
            { key: 'sim', icon: '🪪', title: 'Tahan SIM', sub: 'Diambil dari inventory, ditebus di loket polisi', price: money(D.opts.hold.sim),
              off: !t ? NO_PLAYER : !t.hasSim && 'Tidak membawa SIM' },
            { key: 'stnk', icon: '📄', title: 'Tahan STNK', sub: 'Diambil dari inventory, ditebus di loket polisi', price: money(D.opts.hold.stnk),
              off: !t ? NO_PLAYER : !arr(t.stnks).length && 'Tidak membawa STNK' },
            { key: 'revoke', icon: '🚫', title: 'Cabut Lisensi', sub: 'Kartu diambil, harus buat baru di loket polisi', price: 'SIM / Senjata',
              off: !t ? NO_PLAYER : !D.canRevoke ? `Khusus pangkat ${D.revokeRank} ke atas` : !arr(t.licences).length && 'Tidak punya lisensi aktif' },
            { key: 'seize', icon: '🚓', title: 'Sita Kendaraan', sub: v ? `${v.label || 'Kendaraan'} · ${v.plate}` : 'Ditebus pemilik di loket polisi',
              price: 'Pilih alasan', off: !v && 'Tidak ada kendaraan kosong di dekatmu' },
        ];
    }

    function renderGrid() {
        const parts = [];
        if (D.target) parts.push(D.target.name);
        if (D.vehicle) parts.push(`Plat ${D.vehicle.plate}`);
        $('ad-sub').textContent = parts.join(' · ') || 'Tidak ada orang atau kendaraan di dekatmu';

        $('ad-grid').innerHTML = cards().map((c) => `
            <div class="card ${c.off ? 'off' : ''}">
                <div class="img">${c.icon}</div>
                <h3>${esc(c.title)}</h3>
                <p>${esc(c.sub)}</p>
                <div class="price">${esc(c.price)}</div>
                ${c.off ? `<div class="reason">${esc(c.off)}</div>` : `<button class="open" data-key="${c.key}">Pilih</button>`}
            </div>`).join('');
    }

    function option(id, title, sub, right, radio) {
        const on = picked.includes(id);
        return `<button class="opt ${radio ? 'radio' : ''} ${on ? 'on' : ''}" data-id="${esc(id)}">
            <span class="tick">${on ? '✓' : ''}</span>
            <span class="name">${esc(title)}${sub ? `<span>${esc(sub)}</span>` : ''}</span>
            ${right ? `<b>${esc(right)}</b>` : ''}
        </button>`;
    }

    function noteBox() {
        const old = document.querySelector('#ad-sheet-body textarea');
        return `<div class="label">Catatan (opsional)</div><textarea maxlength="100" placeholder="Contoh: SIM kedaluwarsa">${esc(old ? old.value : '')}</textarea>`;
    }

    function renderSheet() {
        const body = $('ad-sheet-body');
        let html = '';
        let total = null;
        let ready = picked.length > 0;

        if (action === 'fine') {
            $('ad-sheet-title').textContent = 'Denda';
            html = `<div class="info">Tagihan dikirim ke HP ${esc(D.target.name)}. Selama belum dibayar, tercatat di tab Tilang.</div>
                <div class="label">Jenis pelanggaran</div>` +
                arr(D.opts.fines).map((f, i) => option(String(i + 1), f.label, '', money(f.price))).join('');
            total = picked.reduce((s, id) => s + (arr(D.opts.fines)[Number(id) - 1]?.price || 0), 0);
            $('ad-submit').textContent = 'Kirim Tagihan';
        } else if (action === 'sim') {
            $('ad-sheet-title').textContent = 'Tahan SIM';
            html = `<div class="info">SIM ${esc(D.target.name)} diambil dari inventory. Ditebus di loket polisi sebesar ${money(D.opts.hold.sim)}.</div>` + noteBox();
            ready = true;
            $('ad-submit').textContent = 'Tahan SIM';
        } else if (action === 'stnk') {
            $('ad-sheet-title').textContent = 'Tahan STNK';
            html = `<div class="info">Ditebus di loket polisi sebesar ${money(D.opts.hold.stnk)}.</div><div class="label">STNK yang dibawa</div>` +
                arr(D.target.stnks).map((s) => option(String(s.slot), `Plat ${s.plate}`, s.vehicle, '', true)).join('') + noteBox();
            $('ad-submit').textContent = 'Tahan STNK';
        } else if (action === 'revoke') {
            $('ad-sheet-title').textContent = 'Cabut Lisensi';
            html = `<div class="info">Kartu diambil dari inventory ${esc(D.target.name)} dan lisensinya mati. Tidak bisa diperpanjang atau ditebus, harus mengajukan baru di loket polisi.</div>
                <div class="label">Lisensi yang dicabut</div>` +
                arr(D.target.licences).map((l) => option(l.kind, l.label, '', '', true)).join('') + noteBox();
            $('ad-submit').textContent = 'Cabut Lisensi';
        } else if (action === 'seize') {
            $('ad-sheet-title').textContent = 'Sita Kendaraan';
            html = `<div class="info">${esc(D.vehicle.label || 'Kendaraan')} · Plat ${esc(D.vehicle.plate)}. Pemilik menebus di loket polisi, lalu mengambilnya di Impound Lot.</div>
                <div class="label">Alasan sita</div>` +
                arr(D.opts.vehicleReasons).map((r, i) => option(String(i + 1), r.label, '', money(r.price), true)).join('');
            $('ad-submit').textContent = 'Sita Kendaraan';
        }

        body.innerHTML = html;
        $('ad-total-row').classList.toggle('hidden', total === null);
        if (total !== null) $('ad-total').textContent = money(total);
        $('ad-submit').classList.toggle('danger', action === 'seize' || action === 'revoke');
        $('ad-submit').disabled = busy || !ready;
    }

    function openSheet(key) {
        action = key;
        picked = [];
        showMsg('');
        $('ad-sheet-body').innerHTML = '';
        renderSheet();
        $('ad-sheet').classList.remove('hidden');
    }

    function closeSheet() {
        action = null;
        $('ad-sheet').classList.add('hidden');
    }

    function showMsg(text) {
        $('ad-msg').textContent = text;
        $('ad-msg').classList.toggle('hidden', !text);
    }

    function open(data) {
        D = data;
        busy = false;
        closeSheet();
        renderGrid();
        root.classList.remove('hidden');
    }

    function close() {
        root.classList.add('hidden');
        D = null;
        action = null;
    }

    $('ad-grid').addEventListener('click', (e) => {
        const b = e.target.closest('.open');
        if (b) openSheet(b.dataset.key);
    });

    $('ad-sheet-body').addEventListener('click', (e) => {
        const b = e.target.closest('.opt');
        if (!b) return;
        const id = b.dataset.id;
        const multi = action === 'fine';
        if (multi) picked = picked.includes(id) ? picked.filter((x) => x !== id) : [...picked, id];
        else picked = [id];
        showMsg('');
        renderSheet();
    });

    $('ad-sheet-close').addEventListener('click', closeSheet);
    root.querySelector('[data-ad-close]').addEventListener('click', () => post('adminClose'));

    $('ad-submit').addEventListener('click', async () => {
        if (busy || !action) return;
        const note = document.querySelector('#ad-sheet-body textarea')?.value || '';
        const payload = { action };
        if (action === 'fine') payload.indexes = picked.map(Number);
        if (action === 'stnk') payload.slot = Number(picked[0]);
        if (action === 'revoke') payload.kind = picked[0];
        if (action === 'sim' || action === 'stnk' || action === 'revoke') payload.note = note;
        if (action === 'seize') payload.reason = Number(picked[0]);

        busy = true;
        renderSheet();
        const res = await post('adminSubmit', payload);
        busy = false;
        if (!res || !res.ok) {
            showMsg((res && res.msg) || 'Gagal.');
            if (D) renderSheet();
        }
    });

    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape' || root.classList.contains('hidden')) return;
        if (action) closeSheet();
        else post('adminClose');
    });

    window.addEventListener('message', ({ data }) => {
        if (data.type === 'adminOpen') open(data.data);
        else if (data.type === 'adminClose') close();
    });
})();
