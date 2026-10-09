const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_cafe';
const $ = (id) => document.getElementById(id);
const arr = (v) => (Array.isArray(v) ? v : Object.values(v || {}));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID');

const post = (name, data = {}) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
        .then((r) => r.json())
        .catch(() => null);

let M = null;          // data menu
let tab = 'all';
let cart = [];         // { kind, id, label, price, qty }
let method = 'cash';
let busy = false;

/* ---------------- MENU ---------------- */
const clampQty = (v) => Math.max(M.order.min, Math.min(M.order.max, parseInt(v, 10) || M.order.min));

function imgTag(item, emoji) {
    return `<div class="img"><img src="${M.images}${esc(item)}.png" onerror="this.parentNode.textContent='${emoji || '🍽️'}'"></div>`;
}

function qtyControl(value) {
    return `<div class="qty"><button data-step="-1">−</button><input type="number" value="${value}" min="${M.order.min}" max="${M.order.max}"><button data-step="1">+</button></div>`;
}

function renderGrid() {
    let html = '';
    if (tab === 'promo') {
        const promos = arr(M.promos);
        if (!promos.length) html = '<div class="empty">Belum ada promo.</div>';
        for (const p of promos) {
            html += `<div class="card" data-kind="promo" data-id="${p.id}">
                <span class="tag">PROMO</span>
                <div class="img">${esc(p.emoji || '🎁')}</div>
                <h3>${esc(p.label)}</h3>
                <p>${esc(p.foodLabel)} + ${esc(p.drinkLabel)}</p>
                <div class="price">${money(p.price)}${p.normal > p.price ? `<s>${money(p.normal)}</s>` : ''}</div>
                <div class="row">${qtyControl(M.order.default)}<button class="add">Tambah</button></div>
            </div>`;
        }
    } else {
        for (const m of arr(M.menu)) {
            if (tab !== 'all' && m.category !== tab) continue;
            html += `<div class="card" data-kind="item" data-id="${esc(m.item)}">
                ${imgTag(m.item, m.emoji)}
                <h3>${esc(m.label)}</h3>
                <p>${esc(m.desc)}</p>
                <div class="price">${money(m.price)}</div>
                <div class="row">${qtyControl(M.order.default)}<button class="add">Tambah</button></div>
            </div>`;
        }
    }
    $('grid').innerHTML = html;
}

function findProduct(kind, id) {
    if (kind === 'promo') {
        const p = arr(M.promos).find((x) => String(x.id) === String(id));
        return p && { label: p.label, price: p.price, sub: `${p.foodLabel} + ${p.drinkLabel}` };
    }
    const m = arr(M.menu).find((x) => x.item === id);
    return m && { label: m.label, price: m.price };
}

function addToCart(kind, id, qty) {
    const found = cart.find((l) => l.kind === kind && String(l.id) === String(id));
    if (found) {
        found.qty = clampQty(found.qty + qty);
    } else {
        if (cart.length >= 15) return showMsg('Keranjang penuh.');
        const p = findProduct(kind, id);
        if (!p) return;
        cart.push({ kind, id: kind === 'promo' ? Number(id) : id, qty: clampQty(qty), ...p });
    }
    renderCart();
    const btn = $('cart-btn');
    btn.animate([{ transform: 'scale(1.2)' }, { transform: 'scale(1)' }], { duration: 200 });
}

function renderCart() {
    const count = cart.length;
    $('cart-count').textContent = count;
    $('cart-count').classList.toggle('hidden', count === 0);

    if (!count) {
        $('cart-list').innerHTML = '<div class="empty">Keranjang masih kosong.</div>';
    } else {
        $('cart-list').innerHTML = cart.map((l, i) => `
            <div class="line" data-index="${i}">
                <div class="top"><div><b>${esc(l.label)}</b>${l.sub ? `<br><span>${esc(l.sub)}</span>` : ''}</div><b>${money(l.price * l.qty)}</b></div>
                <div class="row">${qtyControl(l.qty)}<button class="remove">Hapus</button></div>
            </div>`).join('');
    }
    $('cart-total').textContent = money(cart.reduce((s, l) => s + l.price * l.qty, 0));
    $('order-btn').disabled = !count || busy;
}

function showMsg(text) {
    const el = $('cart-msg');
    el.textContent = text;
    el.classList.toggle('hidden', !text);
}

function setMethod(m) {
    method = m;
    document.querySelectorAll('.methods button').forEach((b) => b.classList.toggle('active', b.dataset.method === m));
}

function openMenu(data) {
    M = data;
    cart = [];
    tab = 'all';
    busy = false;
    $('m-title').textContent = data.label;
    $('m-sub').textContent = data.npc ? 'Kasir otomatis: pesanan langsung dikirim jika stok tersedia' : 'Pilih menu favoritmu';
    document.querySelectorAll('#tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === 'all'));

    const banner = $('m-banner');
    if (data.active) {
        const st = data.active.status === 'unpaid' ? 'menunggu pembayaran invoice di HP' : 'sudah dibayar, sedang disiapkan';
        banner.textContent = `Pesanan aktif #${data.active.code} (${money(data.active.total)}) ${st}.`;
        banner.classList.remove('hidden');
    } else banner.classList.add('hidden');

    const tr = document.querySelector('[data-method="transfer"]');
    tr.disabled = !data.transfer;
    setMethod('cash');
    showMsg('');
    $('cart').classList.add('hidden');
    renderGrid();
    renderCart();
    $('orders').classList.add('hidden');
    $('menu').classList.remove('hidden');
}

$('tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    tab = b.dataset.tab;
    document.querySelectorAll('#tabs button').forEach((x) => x.classList.toggle('active', x === b));
    renderGrid();
});

function stepQty(e) {
    const step = e.target.closest('[data-step]');
    if (!step) return false;
    const input = step.parentNode.querySelector('input');
    input.value = clampQty(Number(input.value) + Number(step.dataset.step));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
}

$('grid').addEventListener('click', (e) => {
    if (stepQty(e)) return;
    const add = e.target.closest('.add');
    if (!add) return;
    const card = add.closest('.card');
    const input = card.querySelector('input');
    addToCart(card.dataset.kind, card.dataset.id, clampQty(input.value));
    input.value = M.order.default;
});
$('grid').addEventListener('change', (e) => {
    if (e.target.tagName === 'INPUT') e.target.value = clampQty(e.target.value);
});

$('cart-list').addEventListener('click', (e) => {
    if (stepQty(e)) return;
    const rm = e.target.closest('.remove');
    if (!rm) return;
    cart.splice(Number(rm.closest('.line').dataset.index), 1);
    renderCart();
});
$('cart-list').addEventListener('change', (e) => {
    if (e.target.tagName !== 'INPUT') return;
    const line = cart[Number(e.target.closest('.line').dataset.index)];
    if (line) line.qty = clampQty(e.target.value);
    renderCart();
});

$('cart-btn').addEventListener('click', () => $('cart').classList.toggle('hidden'));
$('cart-close').addEventListener('click', () => $('cart').classList.add('hidden'));
document.querySelector('.methods').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (b && !b.disabled) setMethod(b.dataset.method);
});

$('order-btn').addEventListener('click', async () => {
    if (busy || !cart.length) return;
    busy = true;
    showMsg('');
    renderCart();
    const res = await post('order', { cart: cart.map((l) => ({ kind: l.kind, id: l.id, qty: l.qty })), method });
    busy = false;
    if (!res || !res.ok) {
        showMsg((res && res.msg) || 'Order gagal.');
        renderCart();
    }
});

/* ---------------- LIST PEMESANAN ---------------- */
function timeAgo(ts) {
    const s = Math.max(0, Math.floor(Date.now() / 1000 - ts));
    if (s < 60) return 'baru saja';
    if (s < 3600) return Math.floor(s / 60) + ' menit lalu';
    return Math.floor(s / 3600) + ' jam lalu';
}

function renderOrders(list) {
    list = arr(list);
    $('o-sub').textContent = `${list.length} pesanan sudah dibayar`;
    if (!list.length) {
        $('o-list').innerHTML = '<div class="empty">Belum ada pesanan.</div>';
        return;
    }
    $('o-list').innerHTML = list.map((o) => `
        <div class="order">
            <div class="head">
                <div><b>${esc(o.name)}</b><small>#${esc(o.code)} · ${o.method === 'cash' ? 'Cash' : 'Transfer'} · ${timeAgo(o.time)}</small></div>
                <span class="status ${o.ready ? 'ok' : 'no'}">${o.ready ? 'SIAP' : 'BELUM SIAP'}</span>
            </div>
            <div class="items">${arr(o.needs).map((n) => `<div class="${n.have >= n.need ? 'ok' : 'no'}"><span>${esc(n.label)}</span><span>${n.need}x (stok ${n.have})</span></div>`).join('')}</div>
            <div class="lines">${arr(o.lines).map((l) => `${esc(l.label)} x${l.qty}`).join(' · ')} — <b>${money(o.total)}</b></div>
            <button class="serve" data-code="${esc(o.code)}" ${o.ready ? '' : 'disabled'}>Serve Order</button>
        </div>`).join('');
}

async function refreshOrders() {
    renderOrders(await post('refresh'));
}

$('o-refresh').addEventListener('click', refreshOrders);
$('o-list').addEventListener('click', async (e) => {
    const b = e.target.closest('.serve');
    if (!b || b.disabled) return;
    b.disabled = true;
    const res = await post('serve', { code: b.dataset.code });
    if (res && res.ok) refreshOrders();
    else b.disabled = false;
});

/* ---------------- GLOBAL ---------------- */
function closeAll() {
    $('menu').classList.add('hidden');
    $('orders').classList.add('hidden');
}

document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => post('close')));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('cart').classList.contains('hidden') && !$('menu').classList.contains('hidden')) return $('cart').classList.add('hidden');
    post('close');
});

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'openMenu': return openMenu(data.data);
        case 'openOrders':
            $('menu').classList.add('hidden');
            $('orders').classList.remove('hidden');
            return renderOrders(data.data.orders);
        case 'orders': return renderOrders(data.data);
        case 'close': return closeAll();
    }
});
