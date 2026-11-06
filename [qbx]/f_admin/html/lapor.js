'use strict';
// Form laporan warga (/lapor). Memakai helper $, esc, ic, post dari app.js.
(() => {
    const L = { tab: 'new', cat: 0, openId: null, mine: [], cats: [], max: 250, staff: 0 };
    const lreq = (name, data) => post('req', { name, data });
    let lt;

    function ltoast(text, bad) {
        const t = $('#lToast');
        t.className = 'toast ' + (bad ? 'bad' : 'ok');
        t.textContent = text;
        clearTimeout(lt);
        lt = setTimeout(() => t.classList.add('hidden'), 3500);
    }

    const status = (r) => r.status === 'done' ? '<span class="chip green">Selesai</span>'
        : r.status === 'claimed' ? '<span class="chip blue">Ditangani</span>' : '<span class="chip orange">Menunggu</span>';

    async function load() {
        const r = await lreq('lapor_mine');
        if (!r || !r.ok) return;
        Object.assign(L, { mine: r.mine, cats: r.cats, max: r.max, staff: r.staff });
        render();
    }

    function render() {
        $('#lStaff').textContent = L.staff ? `Admin & support online: ${L.staff}` : 'Belum ada staff online, laporan tetap tersimpan';
        document.querySelectorAll('#lTabs button').forEach((b) => b.classList.toggle('active', b.dataset.t === L.tab));
        const pg = $('#lPg');
        pg.classList.toggle('chat', L.tab === 'mine' && L.openId !== null);

        if (L.tab === 'new') {
            const active = L.mine.filter((r) => r.status !== 'done').length;
            pg.innerHTML = `
                <label><span>Kategori</span><div class="filters" id="lCats">${L.cats.map((c, i) => `<button data-c="${i}" class="${i === L.cat ? 'active' : ''}">${esc(c)}</button>`).join('')}</div></label>
                ${L.cat === 1 ? '<label><span>ID pemain yang dilaporkan (opsional)</span><input id="lTarget" type="number" min="1" placeholder="mis. 14"></label>' : ''}
                <label><span>Isi laporan</span><textarea id="lMsg" maxlength="${L.max}" placeholder="Jelaskan singkat: apa yang terjadi dan di mana"></textarea><div class="counter" id="lCnt">0 / ${L.max}</div></label>
                ${active ? `<div class="notice warn">Kamu masih punya ${active} laporan yang belum selesai. Maksimal 2 laporan aktif.</div>` : ''}
                <button class="b b-filled b-block" id="lSend">${ic('send')} Kirim laporan</button>
                <p class="hint t-muted" style="text-align:center">Jeda 60 detik antar laporan. Jangan spam, laporan palsu bisa dikenai sanksi.</p>`;
        } else if (L.openId === null) {
            pg.innerHTML = L.mine.length ? `<div class="group">${L.mine.map((r) => {
                const last = r.msgs[r.msgs.length - 1];
                return `<button class="row" data-open="${r.id}">
                    <div class="t"><b>#${r.id} · ${esc(r.cat)}</b> ${r.unread ? `<span class="bubble" style="margin-left:4px">${r.unread}</span>` : ''}
                        <small>${last.me ? 'Kamu' : 'Staff'}: ${esc(last.t)}</small></div>
                    ${status(r)}<svg class="ic chev"><use href="#i-chev"/></svg>
                </button>`;
            }).join('')}</div>` : '<div class="empty">Belum ada laporan</div>';
        } else {
            const r = L.mine.find((x) => x.id === L.openId);
            if (!r) { L.openId = null; return render(); }
            if (r.unread) { r.unread = 0; lreq('lapor_read', { id: r.id }); }
            const keep = $('#lReply') ? $('#lReply').value : '';
            pg.innerHTML = `
                <div class="rep-h">
                    <button class="icon-btn" id="lBack" title="Kembali">${ic('back')}</button>
                    <div class="t" style="flex:1"><b>#${r.id}</b> <small>${esc(r.cat)}</small></div>
                    ${status(r)}
                </div>
                <div class="thread" id="lThread">${r.msgs.map((m) => m.me
                    ? `<div class="bub me">${esc(m.t)}<small>${m.at}</small></div>`
                    : `<div class="bub st"><span class="who">Staff</span>${esc(m.t)}<small class="t-muted">${m.at}</small></div>`).join('')}</div>
                ${r.status === 'done' ? '<div class="notice" style="text-align:center">Laporan sudah selesai</div>'
                    : `<div class="reply"><input id="lReply" maxlength="${L.max}" placeholder="Balas…"><button class="b b-sm b-tinted" id="lSendReply">${ic('send')}</button></div>`}`;
            if ($('#lReply')) $('#lReply').value = keep;
            $('#lThread').scrollTop = $('#lThread').scrollHeight;
        }
        const un = L.mine.reduce((a, r) => a + (r.unread || 0), 0);
        $('#lUnread').textContent = un;
        $('#lUnread').classList.toggle('hidden', !un);
    }

    $('#lTabs').onclick = (e) => { const b = e.target.closest('button'); if (b) { L.tab = b.dataset.t; L.openId = null; render(); } };
    $('#lPg').oninput = (e) => { if (e.target.id === 'lMsg') $('#lCnt').textContent = `${e.target.value.length} / ${L.max}`; };
    $('#lPg').onkeydown = (e) => { if (e.key === 'Enter' && e.target.id === 'lReply') $('#lSendReply').click(); };
    $('#lPg').onclick = async (e) => {
        const c = e.target.closest('[data-c]');
        if (c) {
            const keep = $('#lMsg').value;
            L.cat = +c.dataset.c; render();
            $('#lMsg').value = keep; $('#lCnt').textContent = `${keep.length} / ${L.max}`;
            return;
        }
        const o = e.target.closest('[data-open]');
        if (o) { L.openId = +o.dataset.open; return render(); }
        if (e.target.closest('#lBack')) { L.openId = null; return render(); }
        const send = e.target.closest('#lSend');
        if (send && !send.disabled) {
            const text = $('#lMsg').value.trim();
            if (!text) return ltoast('Isi laporan dulu.', true);
            send.disabled = true;
            const r = await lreq('lapor_send', { text, cat: L.cats[L.cat], target: $('#lTarget') ? +$('#lTarget').value || null : null });
            send.disabled = false;
            if (!r) return;
            if (!r.ok) return ltoast(r.msg, true);
            L.mine = r.mine; L.tab = 'mine'; L.openId = null; render();
            return;
        }
        const sr = e.target.closest('#lSendReply');
        if (sr && !sr.disabled) {
            const text = $('#lReply').value.trim();
            if (!text) return;
            sr.disabled = true;
            const r = await lreq('lapor_reply', { id: L.openId, text });
            sr.disabled = false;
            if (r && r.ok) { $('#lReply').value = ''; L.mine = r.mine; render(); } else if (r && r.msg) ltoast(r.msg, true);
        }
    };

    function hide() { $('#lapor').classList.add('hidden'); }
    window.laporHide = hide;
    function closeLapor() { hide(); post('close'); }

    document.addEventListener('click', (e) => { if (e.target.closest('[data-lclose]')) closeLapor(); });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('#lapor').classList.contains('hidden')) closeLapor(); });

    window.addEventListener('message', (e) => {
        const m = e.data;
        if (m.action === 'lapor') {
            L.tab = 'new'; L.openId = null;
            $('#lapor').classList.remove('hidden');
            render();
            load();
        } else if (m.action === 'laporRefresh' && !$('#lapor').classList.contains('hidden')) {
            load();
        }
    });
})();
