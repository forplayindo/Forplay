const $ = (id) => document.getElementById(id);
const panel = $('panel');
const btn = $('withdraw');
let method = 'cash';
let busy = false;

const rupiah = (n) => 'Rp ' + Math.floor(n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({ ok: false, msg: 'Server tidak merespons.' }));
}

function showMsg(text) {
    $('msg').textContent = text || '';
    $('msg').classList.toggle('hidden', !text);
}

function render(d) {
    $('sub').textContent = d.label || 'Kantor Gaji';
    $('net').textContent = rupiah(d.net);
    $('net2').textContent = rupiah(d.net);
    $('gross').textContent = rupiah(d.gross);
    $('tax').textContent = '- ' + rupiah(d.tax);
    $('rate').textContent = d.rate;
    $('empty').classList.toggle('hidden', d.gross > 0);
    btn.disabled = !(d.gross > 0);
    showMsg('');
}

document.querySelectorAll('.methods button').forEach((b) => b.addEventListener('click', () => {
    method = b.dataset.method;
    document.querySelectorAll('.methods button').forEach((x) => x.classList.toggle('active', x === b));
}));

btn.addEventListener('click', async () => {
    if (busy || btn.disabled) return;
    busy = true;
    btn.disabled = true;
    btn.textContent = 'Memproses...';
    const res = await post('withdraw', { method });
    busy = false;
    btn.textContent = 'Ambil Uang';
    if (!res.ok) {
        btn.disabled = false;
        showMsg(res.msg || 'Pencairan gagal.');
    }
});

const close = () => post('close');
$('close').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });

window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') {
        render(data.data);
        panel.classList.remove('hidden');
    } else if (data.action === 'close') {
        panel.classList.add('hidden');
    }
});
