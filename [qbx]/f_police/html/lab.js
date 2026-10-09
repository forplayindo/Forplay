// Lab Forensik: pilih kantong bukti -> periksa 10 detik (progress di game) -> hasil identifikasi.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_police';
    const root = document.getElementById('lab');
    const $ = (id) => document.getElementById(id);
    const arr = (v) => (Array.isArray(v) ? v : Object.values(v || {}));
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const post = (name, data = {}) =>
        fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
            .then((r) => r.json())
            .catch(() => null);

    const ICON = { blood: '🩸', sample: '🧬', fingerprint: '🖐️' };
    const KIND = { blood: 'Darah dari TKP', sample: 'Sampel DNA tersangka', fingerprint: 'Sidik jari' };

    const when = (ts) => {
        if (!ts) return '';
        const d = new Date(ts * 1000);
        const p = (n) => String(n).padStart(2, '0');
        return `${p(d.getDate())}-${p(d.getMonth() + 1)}-${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
    };
    const origin = (e) => [e.street, when(e.collectedAt), e.collectedBy && `oleh ${e.collectedBy}`].filter(Boolean).join(' · ');

    function showList(bags) {
        $('lab-sub').textContent = 'Pilih kantong bukti untuk diperiksa (10 detik)';
        $('lab-result').classList.add('hidden');
        $('lab-actions').classList.add('hidden');
        $('lab-grid').classList.remove('hidden');
        const list = arr(bags);
        if (!list.length) {
            $('lab-grid').innerHTML = '<div class="lab-empty">Tidak ada kantong bukti berisi darah, sampel DNA, atau sidik jari di inventory-mu.</div>';
            return;
        }
        $('lab-grid').innerHTML = list.map((b) => `
            <div class="card">
                <div class="img">${ICON[b.kind] || '🧪'}</div>
                <h3>${esc(b.title)}</h3>
                <p>${esc(origin(b) || KIND[b.kind] || '')}</p>
                ${b.bloodtype ? `<div class="price">Gol. darah ${esc(b.bloodtype)}</div>` : ''}
                ${b.identified ? `<span class="tag">Teridentifikasi: ${esc(b.identified)}</span>` : ''}
                <button class="open" data-slot="${b.slot}">Periksa</button>
            </div>`).join('');
    }

    function row(label, value) {
        return `<div class="lab-row"><span>${esc(label)}</span><b>${esc(value)}</b></div>`;
    }

    function showResult(res) {
        const ev = res.evidence || {};
        $('lab-grid').classList.add('hidden');
        $('lab-result').classList.remove('hidden');
        $('lab-actions').classList.remove('hidden');
        $('lab-sub').textContent = `Hasil pemeriksaan · ${ev.title || 'Bukti'}`;

        if (!res.found) {
            $('lab-result').innerHTML = `
                <div class="lab-photo"><div class="pic">❔</div><h2>Tidak dikenal</h2></div>
                <div class="lab-info">
                    <div class="lab-alert bad">Tidak ada kecocokan di database.</div>
                    ${row('Jenis bukti', KIND[ev.kind] || ev.title || '-')}
                    ${row('Asal bukti', origin(ev) || '-')}
                </div>`;
            return;
        }

        const p = res.person || {};
        const photo = p.mugshot ? `<img src="${esc(p.mugshot)}" onerror="this.parentNode.textContent='👤'">` : '👤';
        const status = p.wanted || p.warrants > 0
            ? `<div class="lab-alert bad">⚠️ Dicari · ${p.warrants || 0} warrant aktif</div>`
            : '<div class="lab-alert ok">Tidak ada warrant aktif</div>';
        const matches = arr(res.matches);

        $('lab-result').innerHTML = `
            <div class="lab-photo">
                <div class="pic">${photo}</div>
                <h2>${esc(p.name || '-')}</h2>
                <small>${esc([p.dob, p.sex].filter(Boolean).join(' · '))}</small>
            </div>
            <div class="lab-info">
                ${status}
                ${row('Jenis bukti', KIND[ev.kind] || ev.title || '-')}
                ${row('Golongan darah', ev.bloodtype || p.bloodtype || '-')}
                ${row('Catatan kriminal', `${p.arrests || 0} kali ditangkap`)}
                ${row('Asal bukti', origin(ev) || '-')}
                ${matches.length
                    ? row('Cocok dengan bukti lain', matches.map((m) => `${m.title}${m.street ? ' (' + m.street + ')' : ''}`).join(', '))
                    : ''}
                <div class="lab-hint">Detail lengkap: cari nama ini di MDT.</div>
            </div>`;
    }

    $('lab-grid').addEventListener('click', async (e) => {
        const b = e.target.closest('.open');
        if (!b || b.disabled) return;
        b.disabled = true;
        const res = await post('labAnalyze', { slot: Number(b.dataset.slot) });
        if (!res || !res.ok) b.disabled = false;
    });

    $('lab-back').addEventListener('click', () => post('labReopen'));
    root.querySelectorAll('[data-lab-close]').forEach((b) => b.addEventListener('click', () => post('labClose')));

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !root.classList.contains('hidden')) post('labClose');
    });

    window.addEventListener('message', ({ data }) => {
        if (data.type === 'labOpen') {
            root.classList.remove('hidden');
            showList(data.data);
        } else if (data.type === 'labResult') {
            root.classList.remove('hidden');
            showResult(data.data);
        } else if (data.type === 'labClose') {
            root.classList.add('hidden');
        }
    });
})();
