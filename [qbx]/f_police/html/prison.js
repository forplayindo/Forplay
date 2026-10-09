// Administrasi Penjara: data penahanan dari MDT (tahanan di dekat meja) -> Masukkan ke Penjara.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_police';
    const root = document.getElementById('prison');
    const $ = (id) => document.getElementById(id);
    const arr = (v) => (Array.isArray(v) ? v : Object.values(v || {}));
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const post = (name, data = {}) =>
        fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
            .then((r) => r.json())
            .catch(() => null);

    const when = (ts) => {
        if (!ts) return '';
        const d = new Date(ts * 1000);
        const p = (n) => String(n).padStart(2, '0');
        return `${p(d.getDate())}-${p(d.getMonth() + 1)}-${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
    };

    function booking(b) {
        const charges = arr(b.charges)
            .map((c) => `<span>${esc(c.code)} · ${esc(c.label)}${c.count > 1 ? ' ×' + c.count : ''}</span>`)
            .join('');
        return `
            <div class="pr-booking">
                <div class="top">
                    <div><b>${esc(b.reportRef || b.ref)}</b> ${esc(b.reportTitle || '')}</div>
                    <div>${esc(b.months)} bulan</div>
                </div>
                ${charges ? `<div class="pr-charges">${charges}</div>` : ''}
                <small>Didata oleh ${esc(b.officer || '-')} · ${esc(when(b.createdAt))}</small>
            </div>`;
    }

    function render(data) {
        const list = arr(data && data.prisoners);
        $('pr-sub').textContent = 'Tahanan di dekat meja dengan data penahanan di MDT';
        if (!list.length) {
            $('pr-list').innerHTML = '<div class="lab-empty">Tidak ada tahanan dengan data penahanan MDT di dekat meja.<br>Pastikan tahanan sudah didata di MDT (Jail → Proses) dan berdiri di samping meja.</div>';
            return;
        }
        $('pr-list').innerHTML = list.map((p) => `
            <div class="pr-card">
                <div class="pr-head">
                    <div class="who">
                        <h2>${esc(p.name)}</h2>
                        <small>${esc(p.citizenid)}</small><br>
                        <span class="pr-tag ${p.cuffed ? '' : 'ok'}">${p.cuffed ? 'Diborgol' : 'Tidak diborgol'}</span>
                    </div>
                    <div class="pr-total"><small>Total hukuman</small><strong>${esc(p.months)} bulan</strong></div>
                </div>
                ${arr(p.bookings).map(booking).join('')}
                <div id="pr-msg-${p.id}" class="msg hidden"></div>
                <button class="primary danger" data-serve="${p.id}">Masukkan ke Penjara</button>
            </div>`).join('');
    }

    $('pr-list').addEventListener('click', async (e) => {
        const b = e.target.closest('[data-serve]');
        if (!b || b.disabled) return;
        // klik pertama = konfirmasi
        if (!b.dataset.sure) {
            b.dataset.sure = '1';
            b.textContent = 'Yakin? Klik lagi untuk memasukkan';
            return;
        }
        b.disabled = true;
        b.textContent = 'Memproses...';
        const res = await post('prisonServe', { id: Number(b.dataset.serve) });
        if (res && res.ok) return;
        const msg = $(`pr-msg-${b.dataset.serve}`);
        if (msg) {
            msg.textContent = (res && res.msg) || 'Gagal memproses tahanan.';
            msg.classList.remove('hidden');
        }
        delete b.dataset.sure;
        b.disabled = false;
        b.textContent = 'Masukkan ke Penjara';
    });

    $('pr-refresh').addEventListener('click', () => post('prisonRefresh'));
    root.querySelectorAll('[data-pr-close]').forEach((b) => b.addEventListener('click', () => post('prisonClose')));

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !root.classList.contains('hidden')) post('prisonClose');
    });

    window.addEventListener('message', ({ data }) => {
        if (data.type === 'prisonOpen') {
            root.classList.remove('hidden');
            render(data.data);
        } else if (data.type === 'prisonClose') {
            root.classList.add('hidden');
        }
    });
})();
