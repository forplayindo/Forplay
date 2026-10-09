'use strict';

const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_signs';

const post = (name, data = {}) =>
    fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => null);

const $ = (id) => document.getElementById(id);
const fields = [...document.querySelectorAll('[data-f]')];
const field = (k) => document.querySelector(`[data-f=${k}]`);

const STYLE_LABEL = { led: 'LED', neon: 'Neon' };
const STYLE_HINT = {
    led: 'Huruf tebal timbul. Siang seperti huruf akrilik biasa, malam menyala dari dalam.',
    neon: 'Tabung tipis. Siang terlihat kaca pucat, malam menyala terang dan berpendar.',
};
const VALID_TEXT = /^[ -~]*$/;

const state = { list: [], colors: [], draft: null, maxText: 32 };
let updateTimer = null;
let confirmAction = null;

// ------------------------------------------------------------------
// Daftar papan nama
// ------------------------------------------------------------------

function button(text, cls, onClick) {
    const b = document.createElement('button');
    b.textContent = text;
    b.className = 'small ' + (cls || '');
    b.onclick = onClick;
    return b;
}

function renderList() {
    const q = $('search').value.trim().toLowerCase().replace(/^#/, '');
    const items = state.list.filter((s) => !q || s.text.toLowerCase().includes(q) || String(s.id) === q);
    const list = $('list');
    list.replaceChildren();

    if (!items.length) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = state.list.length ? 'Tidak ada yang cocok' : 'Belum ada papan nama';
        list.appendChild(empty);
        return;
    }

    for (const s of items) {
        const el = document.createElement('div');
        el.className = 'item' + (s.active ? '' : ' off');

        const top = document.createElement('div');
        top.className = 'top';
        const name = document.createElement('div');
        name.className = 'name';
        const dot = document.createElement('div');
        dot.className = 'dot';
        dot.style.background = s.color;
        const text = document.createElement('span');
        text.textContent = s.text; // textContent: aman dari HTML injection
        name.append(dot, text);
        const id = document.createElement('div');
        id.className = 'meta';
        id.textContent = '#' + s.id;
        top.append(name, id);

        const meta = document.createElement('div');
        meta.className = 'meta';
        meta.textContent = [
            STYLE_LABEL[s.style] || s.style,
            s.alwaysOn ? 'Nyala 24 jam' : 'Nyala malam',
            s.dist + ' m',
            s.active ? 'Aktif' : 'Mati',
        ].join(' · ');

        const btns = document.createElement('div');
        btns.className = 'btns';
        btns.append(
            button('Edit', 'primary', () => openForm('edit', { id: s.id })),
            button('Teleport', '', () => post('teleport', { id: s.id })),
            button(s.active ? 'Matikan' : 'Aktifkan', '', () => post('toggle', { id: s.id })),
            button('Hapus', 'danger', () => askConfirm(`Hapus papan nama "${s.text}" (#${s.id})?`, () => post('delete', { id: s.id }))),
        );

        el.append(top, meta, btns);
        list.appendChild(el);
    }
}

// ------------------------------------------------------------------
// Form
// ------------------------------------------------------------------

function showView(view) {
    $('view-list').classList.toggle('hidden', view !== 'list');
    $('view-form').classList.toggle('hidden', view !== 'form');
    $('toast').style.display = 'none';
    if (view === 'list') $('title').textContent = 'Papan Nama';
}

function toast(text) {
    const t = $('toast');
    t.textContent = text;
    t.style.display = 'block';
}

function setStyle(style) {
    document.querySelectorAll('#seg-style button').forEach((b) => b.classList.toggle('on', b.dataset.style === style));
    $('style-hint').textContent = STYLE_HINT[style] || '';
    $('depth-label').textContent = style === 'neon' ? 'Jarak tabung dari tembok' : 'Tebal huruf';
}

function setColor(hex) {
    field('color').value = hex;
    $('color-hex').textContent = hex.toUpperCase();
    document.querySelectorAll('.swatch').forEach((s) => s.classList.toggle('on', s.dataset.color === hex.toLowerCase()));
}

function updateCount() {
    const v = field('text').value;
    const c = $('count');
    if (!VALID_TEXT.test(v)) {
        c.className = 'badge bad';
        c.textContent = 'Ada huruf tidak didukung';
    } else {
        c.className = 'badge' + (v.length > state.maxText ? ' bad' : '');
        c.textContent = `${v.length}/${state.maxText}`;
    }
}

function fillForm(d) {
    state.draft = d;
    $('title').textContent = d.id ? `Edit Papan Nama #${d.id}` : 'Papan Nama Baru';
    for (const el of fields) {
        const v = d[el.dataset.f];
        if (el.type === 'checkbox') el.checked = !!v;
        else el.value = v ?? '';
    }
    setStyle(d.style);
    setColor(d.color);
    updateLabels();
    updateCount();
}

function readForm() {
    const data = { style: state.draft.style };
    for (const el of fields) {
        const k = el.dataset.f;
        if (el.type === 'checkbox') data[k] = el.checked;
        else if (el.type === 'range') data[k] = parseFloat(el.value);
        else data[k] = el.value;
    }
    return data;
}

function updateLabels() {
    $('val-height').textContent = parseFloat(field('height').value).toFixed(2);
    $('val-depth').textContent = field('depth').value;
    $('val-renderDistance').textContent = field('renderDistance').value;
}

// Kirim perubahan ke client (preview langsung di game)
function sendUpdate() {
    clearTimeout(updateTimer);
    updateTimer = setTimeout(async () => {
        if (!state.draft) return;
        const d = await post('update', readForm());
        if (d) state.draft = d;
    }, 80);
}

async function openForm(kind, data) {
    const d = await post(kind, data);
    if (!d) return;
    fillForm(d);
    showView('form');
}

fields.forEach((el) => {
    el.addEventListener('input', () => {
        if (el.dataset.f === 'color') setColor(el.value);
        if (el.dataset.f === 'text') updateCount();
        updateLabels();
        sendUpdate();
    });
});

document.querySelectorAll('#seg-style button').forEach((b) => {
    b.onclick = () => {
        if (!state.draft || state.draft.style === b.dataset.style) return;
        state.draft.style = b.dataset.style;
        setStyle(b.dataset.style);
        sendUpdate();
    };
});

// ------------------------------------------------------------------
// Tombol
// ------------------------------------------------------------------

$('btn-close').onclick = () => post('close');
$('btn-new').onclick = () => openForm('new');
$('search').oninput = renderList;
$('btn-place').onclick = () => post('place');

$('btn-cancel').onclick = async () => {
    const list = await post('cancel');
    state.draft = null;
    if (list) state.list = list;
    renderList();
    showView('list');
};

$('btn-save').onclick = async () => {
    if (!state.draft) return;
    const text = field('text').value.trim();
    if (!text) return toast('Tulisan masih kosong.');
    if (!VALID_TEXT.test(text)) return toast('Hanya huruf, angka, dan simbol standar keyboard.');
    if (text.length > state.maxText) return toast(`Tulisan maksimal ${state.maxText} huruf.`);
    const btn = $('btn-save');
    btn.disabled = true;
    const res = await post('save');
    btn.disabled = false;
    if (res && res.ok) {
        state.draft = null;
        state.list = res.list || state.list;
        renderList();
        showView('list');
    } else if (res && res.err) {
        toast(res.err);
    }
};

function askConfirm(text, action) {
    confirmAction = action;
    $('confirm-text').textContent = text;
    $('confirm').classList.remove('hidden');
}

$('confirm-yes').onclick = () => {
    $('confirm').classList.add('hidden');
    if (confirmAction) confirmAction();
    confirmAction = null;
};
$('confirm-no').onclick = () => {
    $('confirm').classList.add('hidden');
    confirmAction = null;
};

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('confirm').classList.contains('hidden')) return $('confirm-no').onclick();
    if (!$('view-form').classList.contains('hidden')) return $('btn-cancel').onclick();
    post('close');
});

// ------------------------------------------------------------------
// Pesan dari Lua
// ------------------------------------------------------------------

function buildSwatches() {
    const box = $('swatches');
    box.replaceChildren();
    for (const c of state.colors) {
        const b = document.createElement('button');
        b.className = 'swatch';
        b.dataset.color = c.toLowerCase();
        b.style.background = c;
        b.onclick = () => {
            setColor(c);
            sendUpdate();
        };
        box.appendChild(b);
    }
}

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'open': {
            state.list = data.list || [];
            state.colors = data.colors || [];
            state.draft = null;

            const lim = data.limits;
            state.maxText = lim.maxText;
            Object.assign(field('height'), { min: lim.minHeight, max: lim.maxHeight });
            field('depth').max = lim.maxDepth;
            Object.assign(field('renderDistance'), { min: lim.minRender, max: lim.maxRender });
            field('text').maxLength = lim.maxText;
            buildSwatches();

            $('search').value = '';
            renderList();
            showView('list');
            $('panel').classList.remove('hidden');
            break;
        }
        case 'list':
            state.list = data.list || [];
            renderList();
            break;
        case 'hide':
            $('panel').classList.add('hidden');
            break;
        case 'show':
            if (data.draft) fillForm(data.draft);
            $('panel').classList.remove('hidden');
            break;
        case 'close':
            state.draft = null;
            $('confirm').classList.add('hidden');
            $('panel').classList.add('hidden');
            break;
    }
});
