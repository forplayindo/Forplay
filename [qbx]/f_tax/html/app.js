const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_tax';
const $ = (id) => document.getElementById(id);
const arr = (v) => (Array.isArray(v) ? v : Object.values(v || {}));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID');

const post = (name, data = {}) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
        .then((r) => r.json())
        .catch(() => null);

let D = null;        // payload dari server
let histJob = null;  // job yang riwayatnya sedang dibuka
let busy = false;
let confirmTimer = null;

function render() {
    const jobs = arr(D.jobs);
    const audit = D.mode === 'audit';

    $('title').textContent = audit ? 'Audit Pajak' : 'Bayar Pajak';
    if (audit) {
        const total = jobs.reduce((s, j) => s + (j.tax || 0), 0);
        $('sub').textContent = `Tarif ${D.rate}% · Total pajak tertagih ${money(total)}`;
    } else {
        $('sub').textContent = `${jobs[0] ? jobs[0].label : ''} · Tarif pajak ${D.rate}%`;
    }

    $('ratebar').classList.toggle('hidden', !(audit && D.canRate));
    if (audit && D.canRate && document.activeElement !== $('rate')) {
        $('rate').value = D.rate;
        $('rate').min = D.minRate;
        $('rate').max = D.maxRate;
    }

    const cz = audit && D.citizen;
    $('citizen').classList.toggle('hidden', !cz);
    if (cz) {
        $('cz-count').textContent = Number(cz.count || 0).toLocaleString('id-ID');
        $('cz-total').textContent = money(cz.total);
    }

    $('grid').classList.toggle('single', !audit);
    $('grid').innerHTML = jobs.map((j) => {
        const noBank = j.balance === null || j.balance === undefined;
        const short = !noBank && j.balance < j.tax;
        const status = j.tax <= 0 ? '<span class="status ok">TIDAK ADA TAGIHAN</span>'
            : short ? '<span class="status no">SALDO KURANG</span>'
            : '<span class="status due">BELUM BAYAR</span>';
        return `<div class="order" data-job="${esc(j.name)}">
            <div class="head">
                <div><b>${esc(j.label)}</b><small>Terakhir bayar: ${esc(j.lastPaid || '-')}</small></div>
                ${status}
            </div>
            <div class="items">
                <div><span>Jumlah transaksi</span><b>${Number(j.count || 0).toLocaleString('en-US')}</b></div>
                <div><span>Total pendapatan</span><b>${money(j.income)}</b></div>
                <div><span>Saldo rekening</span><b class="${short ? 'no' : ''}">${noBank ? '-' : money(j.balance)}</b></div>
            </div>
            <div class="taxline"><span>Pajak (${D.rate}%)</span><strong>${money(j.tax)}</strong></div>
            <div class="actions">
                <button class="ghost" data-act="hist">Riwayat</button>
                ${audit ? '' : `<button class="primary" data-act="pay" ${j.tax <= 0 || short ? 'disabled' : ''}>Bayar Pajak</button>`}
            </div>
        </div>`;
    }).join('');
}

async function openHistory(job) {
    const j = arr(D.jobs).find((x) => x.name === job);
    histJob = job;
    $('hist-sub').textContent = j ? j.label : job;
    $('hist-list').innerHTML = '<div class="empty">Memuat...</div>';
    $('hist').classList.remove('hidden');
    const rows = await post('history', { job });
    if (histJob !== job) return;
    const list = arr(rows);
    $('hist-list').innerHTML = list.length
        ? list.map((r) => `<div class="line"><span>${esc(r.date)}</span><b>${money(r.amount)}</b></div>`).join('')
        : '<div class="empty">Belum ada riwayat pembayaran.</div>';
}

function closeHistory() {
    histJob = null;
    $('hist').classList.add('hidden');
}

function apply(data) {
    if (!data || data.err) return;
    D = data;
    render();
    if (histJob) openHistory(histJob);
}

async function pay(btn) {
    if (busy) return;
    const j = arr(D.jobs)[0];
    if (!btn.classList.contains('confirm')) {
        btn.classList.add('confirm');
        btn.textContent = `Konfirmasi bayar ${money(j.tax)}`;
        clearTimeout(confirmTimer);
        confirmTimer = setTimeout(() => render(), 4000);
        return;
    }
    clearTimeout(confirmTimer);
    busy = true;
    btn.disabled = true;
    btn.textContent = 'Memproses...';
    const res = await post('pay');
    busy = false;
    if (res && res.data) apply(res.data); else render();
}

$('grid').addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-act]');
    if (!btn) return;
    const job = btn.closest('.order').dataset.job;
    if (btn.dataset.act === 'hist') openHistory(job);
    else if (btn.dataset.act === 'pay') pay(btn);
});

$('rate-save').addEventListener('click', async () => {
    if (busy) return;
    const v = parseFloat($('rate').value);
    if (isNaN(v)) return;
    busy = true;
    const res = await post('setRate', { rate: v });
    busy = false;
    $('rate').blur();
    if (res && res.data) apply(res.data);
});

$('refresh').addEventListener('click', async () => {
    const data = await post('refresh');
    if (data) apply(data);
});

$('hist-close').addEventListener('click', closeHistory);
$('close').addEventListener('click', () => post('close'));
document.addEventListener('keyup', (e) => { if (e.key === 'Escape') post('close'); });

window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    if (action === 'open') {
        D = data;
        closeHistory();
        $('app').classList.remove('hidden');
        render();
        if (D.mode === 'pay' && arr(D.jobs)[0]) openHistory(arr(D.jobs)[0].name);
    } else if (action === 'close') {
        clearTimeout(confirmTimer);
        closeHistory();
        $('app').classList.add('hidden');
    }
});
