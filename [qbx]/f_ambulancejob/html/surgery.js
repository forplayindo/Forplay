// Panel Operasi (Dokter): tahap berurutan dengan progress bar di game. Obat & jatah Surgical Kit dari Stok Gudang;
// dokter wajib membawa Surgery Bag yang masih berlaku.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_ambulancejob';
    const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) })
        .then(r => r.json()).catch(() => null);
    const $ = id => document.getElementById(id);

    let d = null;
    let confirmCancel = false;

    const stockOf = step => {
        if (step.kit) return { have: d.bag && d.stock.kit >= d.kitWear, text: `Surgical Kit · jatah gudang ${d.stock.kit}` };
        if (!step.itemKey) return { have: true, text: 'Tanpa item' };
        const n = d.stock[step.itemKey] || 0;
        return { have: d.bag && n > 0, text: `${step.item} ×1 · stok ${n}` };
    };

    function render() {
        $('sr-sub').textContent = `${d.table} · ${d.patient}`;
        const tf = d.transfusion;
        const bloodLow = d.blood < tf.need;
        const bags = d.stock.bloodBag || 0;
        $('sr-side').innerHTML = `
            ${d.bag ? '' : '<div class="msg">🧳 Kamu tidak membawa <b>Surgery Bag</b> yang masih berlaku. Ambil di Armory.</div>'}
            <h3>Pasien</h3>
            <div class="vital ${bloodLow ? 'bad' : d.blood < 60 ? 'warn' : 'good'}"><small>Darah</small><b>${d.blood}%</b></div>
            <div class="vital ${d.bleed >= 3 ? 'bad' : d.bleed ? 'warn' : 'good'}"><small>Pendarahan</small><b>${d.bleed ? 'Level ' + d.bleed : 'Tidak berdarah'}</b></div>
            <h3>Luka pasien</h3>
            ${d.parts.length ? d.parts.map(p => `<div class="sr-part">⚕️ ${p.label}${p.surgery ? ' · <b style="color:var(--red)">berat</b>' : ''}${p.stabilized ? ' · distabilkan' : ''}</div>`).join('')
                : '<div class="empty">Tidak ada luka tercatat</div>'}
            ${bloodLow ? `<div class="msg">Darah pasien di bawah ${tf.need}%. Tahap berikutnya otomatis transfusi (Blood Bag dari Stok Gudang), atau transfusi sekarang:</div>
                <button class="primary" id="sr-transfuse" ${bags && d.bag ? '' : 'disabled'}>${bags
                    ? `🩸 Transfusi · ${tf.item} ×1 · stok ${bags} · ${Math.round(tf.duration / 1000)} detik`
                    : `Stok ${tf.item} di gudang habis`}</button>` : ''}
            <div style="flex:1"></div>
            <button class="ghost" id="sr-cancel">${confirmCancel ? 'Yakin batalkan? Klik lagi' : 'Batalkan Operasi'}</button>`;

        $('sr-steps').innerHTML = '<h3>Tahap operasi</h3>' + d.steps.map((s, i) => {
            const idx = i + 1, isNext = idx === d.next;
            let st = stockOf(s);
            // tahap yang butuh darah: transfusi ikut otomatis kalau darah kurang
            if (s.needBlood && d.blood < s.needBlood) {
                st = { have: st.have && bags > 0, text: `${st.text} + ${tf.item} ×1 (transfusi, stok ${bags})` };
            }
            return `<div class="sr-step ${s.done ? 'done' : isNext ? 'next' : ''}">
                <span class="num">${s.done ? '✔' : idx}</span>
                <div class="name"><b>${s.label}</b><span>${s.desc || ''}</span>
                    <span>${Math.round(s.duration / 1000)} detik · ${st.text}</span></div>
                ${isNext ? `<button class="primary" data-step="${idx}" ${st.have ? '' : 'disabled'}>${st.have ? 'Mulai' : d.bag ? 'Stok kurang' : 'Butuh Surgery Bag'}</button>` : ''}
            </div>`;
        }).join('');

        $('sr-steps').querySelectorAll('[data-step]').forEach(b => b.onclick = () => post('srStep', { step: Number(b.dataset.step) }));
        if ($('sr-transfuse')) $('sr-transfuse').onclick = () => post('srStep', { step: 'transfusion' });
        $('sr-cancel').onclick = () => {
            if (!confirmCancel) { confirmCancel = true; return render(); }
            confirmCancel = false;
            post('srCancel');
        };
    }

    $('sr-close').onclick = () => post('srClose');
    document.addEventListener('keyup', e => {
        if (e.key === 'Escape' && !$('surgery').classList.contains('hidden')) post('srClose');
    });

    window.addEventListener('message', e => {
        const m = e.data || {};
        if (m.action === 'surgeryOpen') {
            d = m.data; confirmCancel = false;
            render();
            $('surgery').classList.remove('hidden');
        } else if (m.action === 'surgeryHide' || m.action === 'surgeryClose') {
            $('surgery').classList.add('hidden');
        }
    });
})();
