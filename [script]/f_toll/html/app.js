const $ = (id) => document.getElementById(id);
const rp = (n) => 'Rp ' + Math.round(n || 0).toLocaleString('id-ID');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function post(name, body) {
	return fetch(`https://${GetParentResourceName()}/${name}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(body || {}),
	}).then((r) => r.json()).catch(() => null);
}

function close() {
	$('loket').classList.add('hidden');
	$('editor').classList.add('hidden');
	post('close');
}

function showMsg(el, text, ok) {
	el.textContent = text || '';
	el.className = 'msg' + (ok ? ' ok' : '');
	el.classList.toggle('hidden', !text);
}

/* ------------------------------------------------------------------ */
/* Loket                                                               */
/* ------------------------------------------------------------------ */

let loket = null;
let serial = null;
let method = 'cash';
let busy = false;

function amount() {
	return Math.max(0, Math.floor(Number($('amount').value) || 0));
}

function renderLoket() {
	const d = loket;
	const cards = $('cards');
	cards.innerHTML = '';
	if (!d.cards.find((c) => c.serial === serial)) serial = d.cards[0] ? d.cards[0].serial : null;

	d.cards.forEach((c) => {
		const row = document.createElement('button');
		row.className = 'row' + (c.serial === serial ? ' sel' : '');
		row.innerHTML = `<span class="sq" style="--c: var(--accent)"><svg class="ic"><use href="#i-card"/></svg></span>
			<span class="t"><b>${esc(c.serial)}</b><small>${c.trip ? 'Masuk: ' + esc(c.trip) : 'Tidak dalam perjalanan'}</small></span>
			<span class="d money">${rp(c.balance)}</span>`;
		row.onclick = () => { serial = c.serial; renderLoket(); };
		cards.appendChild(row);
	});
	cards.classList.toggle('hidden', d.cards.length === 0);
	$('nocard').classList.toggle('hidden', d.cards.length > 0);

	const has = !!serial;
	$('topup').classList.toggle('hidden', !has);
	$('doTopup').classList.toggle('hidden', !has);

	$('cash').textContent = rp(d.cash);
	$('bank').textContent = rp(d.bank);
	document.querySelectorAll('.methods button').forEach((b) => b.classList.toggle('active', b.dataset.m === method));

	const quick = $('quick');
	quick.innerHTML = '';
	d.topups.forEach((v) => {
		const b = document.createElement('button');
		b.textContent = v >= 1000000 ? (v / 1000000).toLocaleString('id-ID') + 'jt' : (v / 1000).toLocaleString('id-ID') + 'rb';
		b.classList.toggle('active', amount() === v);
		b.onclick = () => { $('amount').value = v; renderLoket(); };
		quick.appendChild(b);
	});

	const a = amount();
	$('doTopup').textContent = a > 0 ? `Isi Saldo ${rp(a)}` : 'Isi Saldo';
	$('doTopup').disabled = busy || a < d.min;
	$('buy').textContent = `Beli Kartu Baru · ${rp(d.price)}`;
	$('buy').disabled = busy;
}

function openLoket(d) {
	loket = d;
	method = 'cash';
	$('amount').value = '';
	showMsg($('msg'), '');
	$('editor').classList.add('hidden');
	$('loket').classList.remove('hidden');
	renderLoket();
}

async function loketAction(name, body) {
	if (busy) return;
	busy = true;
	renderLoket();
	const res = await post(name, body);
	busy = false;
	if (res && res.data) loket = res.data;
	showMsg($('msg'), res ? res.msg || (res.ok ? '' : 'Gagal.') : 'Gagal.', res && res.ok);
	if (res && res.ok && name === 'topup') $('amount').value = '';
	renderLoket();
}

$('amount').addEventListener('input', () => renderLoket());
document.querySelectorAll('.methods button').forEach((b) => {
	b.onclick = () => { method = b.dataset.m; renderLoket(); };
});
$('buy').onclick = () => loketAction('buyCard', { method });
$('doTopup').onclick = () => {
	const a = amount();
	if (a > loket.max) return showMsg($('msg'), `Saldo maksimal kartu ${rp(loket.max)}.`);
	loketAction('topup', { serial, amount: a, method });
};

/* ------------------------------------------------------------------ */
/* Editor                                                              */
/* ------------------------------------------------------------------ */

let editorData = null;

function renderEditor() {
	const box = $('gates');
	const top = box.scrollTop; // jangan lompat ke atas setelah aksi
	box.innerHTML = '';

	editorData.gates.forEach((g) => {
		const wrap = document.createElement('div');
		wrap.className = 'gate';
		wrap.innerHTML = `<div class="gate-h">
				<span class="name">${esc(g.label)}<small>${esc(g.id)} · ${g.lanes.length} lajur</small></span>
				<button class="pill" data-a="tp">TP</button>
				<button class="pill" data-a="loket">${g.loket ? 'Pindah Loket' : 'Set Loket'}</button>
				${g.loket ? '<button class="pill red" data-a="loketDelete">Hapus Loket</button>' : ''}
				<button class="cap tint" data-a="add">+ Lajur</button>
			</div>`;
		const group = document.createElement('div');
		group.className = 'group icons';
		if (g.lanes.length === 0) group.innerHTML = '<div class="none">Belum ada lajur. Tekan "+ Lajur", lalu ikuti petunjuk di layar.</div>';
		g.lanes.forEach((l) => {
			const north = l.dir === 'Ke Paleto';
			const row = document.createElement('div');
			row.className = 'row';
			row.innerHTML = `<span class="sq ${north ? 'n' : 's'}"><svg class="ic"><use href="#i-${north ? 'up' : 'down'}"/></svg></span>
				<span class="t">Lajur ${esc(l.dir)}<small>${l.x.toFixed(1)}, ${l.y.toFixed(1)}</small></span>
				<span class="row-btns">
					<button class="pill" data-a="test">Tes Buka</button>
					<button class="pill" data-a="tp">TP</button>
					<button class="pill red" data-a="delete">Hapus</button>
				</span>`;
			row.querySelectorAll('button').forEach((b) => { b.onclick = () => editorAction(b.dataset.a, { id: l.id, gate: g.id }); });
			group.appendChild(row);
		});
		wrap.querySelectorAll('.gate-h button').forEach((b) => { b.onclick = () => editorAction(b.dataset.a, { gate: g.id }); });
		wrap.appendChild(group);
		box.appendChild(wrap);
	});

	box.scrollTop = top;
}

async function editorAction(a, body) {
	if (a === 'delete' && !confirmDelete(body.id)) return;
	const res = await post('editor:' + a, body);
	if (!res || res === 1) return;
	if (res.data) { editorData = res.data; renderEditor(); }
	showMsg($('emsg'), res.ok ? '' : res.msg, false);
}

let pendingDelete = null;
function confirmDelete(id) {
	// klik "Hapus" dua kali dalam 3 detik
	if (pendingDelete === id) { pendingDelete = null; return true; }
	pendingDelete = id;
	showMsg($('emsg'), 'Klik "Hapus" sekali lagi untuk menghapus lajur ini.', false);
	setTimeout(() => { if (pendingDelete === id) { pendingDelete = null; showMsg($('emsg'), ''); } }, 3000);
	return false;
}

function openEditor(d) {
	editorData = d;
	$('loket').classList.add('hidden');
	const wasHidden = $('editor').classList.contains('hidden');
	$('editor').classList.remove('hidden');
	if (wasHidden) showMsg($('emsg'), '');
	renderEditor();
}

/* ------------------------------------------------------------------ */

document.querySelectorAll('[data-close]').forEach((b) => { b.onclick = close; });
document.addEventListener('keyup', (e) => { if (e.key === 'Escape') close(); });

window.addEventListener('message', (e) => {
	const m = e.data || {};
	if (m.action === 'loket') openLoket(m.data);
	else if (m.action === 'editor') openEditor(m.data);
	else if (m.action === 'close') {
		$('loket').classList.add('hidden');
		$('editor').classList.add('hidden');
	}
});
