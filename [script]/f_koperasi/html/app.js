const $ = (id) => document.getElementById(id);
const panel = $('panel');
let D = null;            // menu dari server
let qty = {};            // item -> jumlah yang dijual
let rows = {};           // item -> data baris
let busy = false;

const rupiah = (n) => 'Rp ' + Math.floor(n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

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

function render() {
    const list = $('list');
    const scroll = list.scrollTop;
    qty = {};
    rows = {};
    list.innerHTML = D.categories.map((cat) => `<div>
        <div class="group-h">${esc(cat.label)}</div>
        <div class="group icons">${cat.rows.map((r) => {
            rows[r.item] = r;
            qty[r.item] = 0;
            const off = r.count === 0;
            return `<div class="row item-row ${off ? 'off' : ''}" data-item="${esc(r.item)}">
                <span class="img" style="background-image:url('nui://ox_inventory/web/images/${esc(r.item)}.png')"></span>
                <span class="t">${esc(r.label)}<small>Punya <b>${r.count}</b> · ${rupiah(r.price)}/buah</small></span>
                <span class="stepper"><button class="circle" data-step="-1" ${off ? 'disabled' : ''}>−</button>
                <input type="number" min="0" value="0" ${off ? 'disabled' : ''}>
                <button class="circle" data-step="1" ${off ? 'disabled' : ''}>+</button></span></div>`;
        }).join('')}</div></div>`).join('');
    list.scrollTop = scroll;
    $('s-rate').textContent = D.taxRate;
    updateSum();
}

// ubah satu baris di tempat (daftar tidak dirender ulang, scroll tidak lompat)
function setQty(item, v) {
    const r = rows[item];
    qty[item] = Math.max(0, Math.min(r.count, Math.floor(v || 0)));
    const row = document.querySelector(`#list [data-item="${item}"]`);
    row.querySelector('input').value = qty[item];
    row.classList.toggle('on', qty[item] > 0);
    updateSum();
}

function updateSum() {
    let gross = 0;
    for (const item in qty) gross += qty[item] * rows[item].price;
    const tax = Math.floor(gross * D.taxRate / 100 + 0.5);
    $('s-gross').textContent = rupiah(gross);
    $('s-tax').textContent = gross ? '-' + rupiah(tax) : rupiah(0);
    $('s-net').textContent = rupiah(gross - tax);
    $('sell').disabled = !gross || busy;
    $('sell').textContent = gross ? `Jual · ${rupiah(gross - tax)}` : 'Jual';
}

$('list').addEventListener('click', (e) => {
    const b = e.target.closest('[data-step]');
    if (!b || b.disabled) return;
    const item = b.closest('[data-item]').dataset.item;
    setQty(item, qty[item] + Number(b.dataset.step));
});

$('list').addEventListener('change', (e) => {
    if (e.target.tagName !== 'INPUT') return;
    setQty(e.target.closest('[data-item]').dataset.item, Number(e.target.value));
});

$('all').addEventListener('click', () => {
    const allSet = Object.keys(rows).every((item) => qty[item] === rows[item].count);
    Object.keys(rows).forEach((item) => setQty(item, allSet ? 0 : rows[item].count));
});

$('sell').addEventListener('click', async () => {
    if (busy) return;
    const items = {};
    for (const item in qty) if (qty[item] > 0) items[item] = qty[item];
    if (!Object.keys(items).length) return;
    busy = true;
    updateSum();
    const res = await post('sell', { items });
    busy = false;
    if (res.ok) {
        const fresh = await post('refresh');
        if (fresh) D = fresh;
        render();
        showMsg(`Terjual ${rupiah(res.gross)} · pajak ${rupiah(res.tax)} · ${rupiah(res.net)} masuk rekening`, true);
    } else {
        showMsg(res.msg || 'Penjualan gagal.');
        updateSum();
    }
});

function close() {
    panel.classList.add('hidden');
    D = null;
    post('close');
}

$('close').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && D) close(); });

window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    if (action === 'open') {
        D = data;
        showMsg('');
        $('list').scrollTop = 0;
        render();
        panel.classList.remove('hidden');
    } else if (action === 'close') {
        panel.classList.add('hidden');
        D = null;
    }
});
