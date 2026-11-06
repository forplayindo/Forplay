// Apotek: warga memesan obat (stok gudang dikunci), lalu membayar di Kasir.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_ambulancejob';
    const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) })
        .then(r => r.json()).catch(() => null);
    const $ = id => document.getElementById(id);
    const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
    const money = n => 'Rp ' + Number(n || 0).toLocaleString('id-ID');
    const clock = ts => { const d = new Date(ts * 1000); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };

    let menu = null;
    let cart = {};
    let msg = null;       // { ok, text }

    const msgHtml = () => msg ? `<div class="${msg.ok ? 'empty' : 'msg'}">${esc(msg.text)}</div>` : '';
    const count = () => Object.values(cart).reduce((a, b) => a + b, 0);
    const total = () => menu.items.reduce((s, m) => s + (cart[m.item] || 0) * m.price, 0);

    // gambar ulang tanpa melompat ke atas (tombol +/− di bawah tetap di posisi)
    function render() {
        const body = $('ph-body'), top = body.scrollTop;
        draw();
        body.scrollTop = top;
    }

    function draw() {
        $('ph-title').textContent = menu.label;
        $('ph-sub').textContent = menu.ems > 0 ? `${menu.ems} petugas EMS bertugas` : 'Tidak ada petugas EMS bertugas';
        const body = $('ph-body'), foot = $('ph-foot');
        let h = msgHtml();

        if (menu.active) {
            const a = menu.active;
            h += `<div class="ph-status"><h2>Pesanan #${a.id} · ${money(a.total)}</h2>
                <span class="chip info" style="align-self:flex-start">Menunggu pembayaran</span>
                <div class="note">Silakan menuju <b>Kasir rumah sakit</b> untuk membayar. Pesanan batal otomatis pukul
                    <b>${clock(a.created + menu.timeout * 60)}</b> kalau belum dibayar, dan stok dikembalikan.</div>
                <div class="note">Kamu belum bisa memesan lagi sampai pesanan ini lunas atau batal.</div></div>`;
            body.innerHTML = h;
            foot.classList.add('hidden');
            return;
        }

        if (menu.cooldown > 0) {
            h += `<div class="ph-status"><h2>Kamu baru saja membeli obat</h2>
                <div class="note">Bisa memesan lagi dalam ${Math.ceil(menu.cooldown / 60)} menit, atau setelah ada petugas EMS bertugas.</div></div>`;
            body.innerHTML = h;
            foot.classList.add('hidden');
            return;
        }

        h += menu.ems > 0
            ? `<div class="note">🟢 Ada <b>${menu.ems} petugas EMS</b> bertugas · maksimal <b>${menu.limit} obat</b> per pesanan · setelah bayar, obat diserahkan petugas di kasir.</div>`
            : `<div class="note">⚠️ Tidak ada EMS bertugas · maksimal <b>${menu.limit} obat</b>, lalu tidak bisa memesan lagi selama 1 jam (atau sampai ada EMS bertugas). Obat langsung masuk tas setelah dibayar di kasir.</div>`;
        h += '<div class="ph-grid">' + menu.items.map(m => {
            const q = cart[m.item] || 0, out = m.stock <= 0;
            return `<div class="ph-item ${out ? 'out' : ''}">
                <div class="img">${m.emoji || '💊'}</div>
                <h3>${esc(m.label)}</h3><p>${esc(m.desc || '')}</p>
                <div class="price">${money(m.price)}</div>
                <div class="stockline">${out ? 'Stok habis' : 'Stok tersedia'}</div>
                <div class="qty"><button data-dec="${m.item}" ${q <= 0 ? 'disabled' : ''}>−</button><b>${q}</b>
                    <button data-inc="${m.item}" ${out || q >= m.stock || count() >= menu.limit ? 'disabled' : ''}>+</button></div></div>`;
        }).join('') + '</div>';
        body.innerHTML = h;

        foot.classList.remove('hidden');
        foot.innerHTML = `<div class="sum"><small>${count()} / ${menu.limit} obat</small><strong>${money(total())}</strong></div>
            <button class="primary" id="ph-order" ${count() === 0 ? 'disabled' : ''}>Pesan &amp; Bayar di Kasir</button>`;

        body.querySelectorAll('[data-inc]').forEach(b => b.onclick = () => {
            if (count() >= menu.limit) return;
            cart[b.dataset.inc] = (cart[b.dataset.inc] || 0) + 1; msg = null; render();
        });
        body.querySelectorAll('[data-dec]').forEach(b => b.onclick = () => {
            cart[b.dataset.dec] = Math.max(0, (cart[b.dataset.dec] || 0) - 1); msg = null; render();
        });
        $('ph-order').onclick = async () => {
            $('ph-order').disabled = true;
            const res = await post('phOrder', { cart });
            if (res && res.ordered) {
                cart = {}; menu = res;
                msg = { ok: true, text: `Pesanan #${res.ordered.id} dibuat. Bayar ${money(res.ordered.total)} di kasir.` };
            } else {
                msg = { ok: false, text: (res && res.error) || 'Gagal memesan' };
                const fresh = await post('phMenu');
                if (fresh && !fresh.error) menu = fresh;
            }
            render();
        };
    }

    $('ph-close').onclick = () => post('phClose');
    document.addEventListener('keyup', e => {
        if (e.key === 'Escape' && !$('pharmacy').classList.contains('hidden')) post('phClose');
    });

    window.addEventListener('message', e => {
        const d = e.data || {};
        if (d.action === 'pharmacyOpen') {
            menu = d.data; msg = null; cart = {};
            render();
            $('ph-body').scrollTop = 0;
            $('pharmacy').classList.remove('hidden');
        } else if (d.action === 'pharmacyClose') {
            $('pharmacy').classList.add('hidden');
        }
    });
})();
