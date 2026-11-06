const $ = (id) => document.getElementById(id);
const rp = (n) => 'Rp ' + Math.round(n || 0).toLocaleString('id-ID');
const fmtL = (n) => Number(n || 0).toLocaleString('id-ID', { maximumFractionDigits: 1 });

let data = null;
let type = null;
let method = 'cash';

function post(name, body) {
	return fetch(`https://${GetParentResourceName()}/${name}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(body || {}),
	}).catch(() => {});
}

function maxLiters() {
	return Math.max(1, Math.floor(data.free));
}

function liters() {
	return Math.min(maxLiters(), Math.max(1, Math.floor(Number($('liters').value) || 1)));
}

function setLiters(n) {
	n = Math.min(maxLiters(), Math.max(1, Math.floor(n)));
	$('liters').value = n;
	$('slider').value = n;
	render();
}

function render() {
	if (!data || !type) return;

	const l = liters();
	const total = Math.ceil(l * type.price);
	const balance = data[method] || 0;

	$('tankNow').style.width = (data.current / data.tank * 100) + '%';
	$('tankAdd').style.width = (l / data.tank * 100) + '%';
	const u = data.unit || 'L';
	$('tankText').textContent = `${fmtL(data.current)} ${u} + ${l} ${u}  /  ${data.tank} ${u}`;

	$('unit').textContent = `${rp(type.price)} / ${u}  ×  ${l} ${u}`;
	$('total').textContent = rp(total);

	const msg = $('msg');
	if (total > balance) {
		msg.textContent = method === 'cash' ? 'Uang cash tidak cukup.' : 'Saldo bank tidak cukup.';
		msg.classList.remove('hidden');
		$('go').disabled = true;
	} else {
		msg.classList.add('hidden');
		$('go').disabled = false;
	}
}

function buildTypes() {
	const box = $('types');
	box.innerHTML = '';

	data.types.forEach((t) => {
		const el = document.createElement('button');
		el.className = 'type' + (t.id === type.id ? ' active' : '');
		el.style.setProperty('--c', t.color);
		const sub = t.ron ? `RON ${t.ron}` : (data.unit || 'L');
		el.innerHTML = `<b>${t.label}</b><span class="ron">${sub}</span><span class="price">${rp(t.price)}</span>`;
		el.onclick = () => { type = t; buildTypes(); render(); };
		box.appendChild(el);
	});
}

function open(d) {
	data = d;
	type = d.types.find((t) => t.id === d.lastType) || d.types[0];
	method = 'cash';

	const u = d.unit || 'L';
	$('veh').textContent = d.label;
	$('title').textContent = d.electric ? 'Isi Daya' : 'Isi Bensin';
	$('logo').innerHTML = `<svg class="ic"><use href="#${d.electric ? 'i-plug' : 'i-fuel'}"/></svg>`;
	$('unitInput').textContent = u;
	$('types').classList.toggle('single', d.types.length === 1);
	document.querySelectorAll('.quick button').forEach((b) => {
		b.textContent = b.dataset.l === 'full' ? 'Penuh' : `${b.dataset.l} ${u}`;
	});
	$('cash').textContent = rp(d.cash);
	$('bank').textContent = rp(d.bank);
	document.querySelectorAll('.methods button').forEach((b) => b.classList.toggle('active', b.dataset.m === method));

	$('slider').max = maxLiters();
	$('liters').max = maxLiters();
	buildTypes();
	setLiters(maxLiters());

	$('panel').classList.remove('hidden');
}

function close(send) {
	$('panel').classList.add('hidden');
	data = null;
	if (send) post('close');
}

window.addEventListener('message', (e) => {
	if (e.data?.action === 'open') open(e.data.data);
	if (e.data?.action === 'close') close(false);
});

$('slider').addEventListener('input', (e) => setLiters(Number(e.target.value)));
$('liters').addEventListener('input', render);
$('liters').addEventListener('change', () => setLiters(liters()));

document.querySelectorAll('.quick button').forEach((b) => {
	b.onclick = () => setLiters(b.dataset.l === 'full' ? maxLiters() : Number(b.dataset.l));
});

document.querySelectorAll('.methods button').forEach((b) => {
	b.onclick = () => {
		method = b.dataset.m;
		document.querySelectorAll('.methods button').forEach((x) => x.classList.toggle('active', x === b));
		render();
	};
});

$('go').onclick = () => {
	if (!data || $('go').disabled) return;
	const body = { type: type.id, liters: liters(), method };
	close(false);
	post('confirm', body);
};

$('close').onclick = () => close(true);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && data) close(true); });
