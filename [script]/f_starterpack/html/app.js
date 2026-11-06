const $ = (id) => document.getElementById(id);
const panel = $('panel');
const btn = $('claim');
let busy = false;

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const safeName = (s) => String(s ?? '').replace(/[^a-zA-Z0-9_-]/g, '');

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

function itemFallback(img) {
    img.parentElement.innerHTML = '<svg class="ic"><use href="#i-box"/></svg>';
}

// gambar kendaraan bersama (f_vehimages), lalu docs FiveM, lalu ikon mobil
function vehImage(model) {
    const img = $('veh-img');
    const fallback = document.querySelector('.veh-img .fallback');
    const sources = [`nui://f_vehimages/images/${model}.webp`, `https://docs.fivem.net/vehicles/${model}.webp`];
    let i = 0;
    img.classList.remove('hidden');
    fallback.classList.add('hidden');
    img.onerror = () => {
        i += 1;
        if (i < sources.length) { img.src = sources[i]; return; }
        img.classList.add('hidden');
        fallback.classList.remove('hidden');
    };
    img.src = sources[0];
}

function setClaimed(claimed) {
    btn.disabled = claimed;
    btn.textContent = claimed ? 'Sudah Diklaim' : 'Klaim Starterpack';
}

function render(d) {
    $('title').textContent = d.title || 'Selamat Datang';
    $('message').textContent = d.message || '';

    $('items').innerHTML = (d.items || []).map((it) => `
        <div class="row">
            <span class="item-ic"><img src="nui://ox_inventory/web/images/${safeName(it.name)}.png" onerror="itemFallback(this)"></span>
            <span class="t">${esc(it.label)}</span>
            <span class="d"><b>x${Number(it.amount) || 0}</b></span>
        </div>`).join('');

    $('vehicle').classList.toggle('hidden', !d.vehicle);
    if (d.vehicle) {
        $('veh-label').textContent = d.vehicle.label || d.vehicle.model;
        vehImage(safeName(d.vehicle.model));
    }

    setClaimed(!!d.claimed);
    showMsg(d.claimed ? 'Karakter ini sudah mengambil starterpack.' : '', d.claimed);
}

btn.addEventListener('click', async () => {
    if (busy || btn.disabled) return;
    busy = true;
    btn.disabled = true;
    btn.textContent = 'Memproses...';
    showMsg('');
    const res = await post('claim');
    busy = false;
    if (!res.ok) {
        setClaimed(false);
        showMsg(res.msg || 'Klaim gagal.');
    }
});

const close = () => { if (!busy) post('close'); };
$('close').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });

window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') {
        busy = false;
        render(data.data);
        panel.classList.remove('hidden');
    } else if (data.action === 'close') {
        panel.classList.add('hidden');
    }
});
