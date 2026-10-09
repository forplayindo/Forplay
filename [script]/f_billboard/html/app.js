'use strict';

const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_billboard';

const post = (name, data = {}) =>
    fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => null);

const $ = (id) => document.getElementById(id);
const fields = [...document.querySelectorAll('[data-f]')];

const MEDIA_LABEL = { image: 'Gambar', video: 'Video', youtube: 'YouTube' };

const state = { list: [], presets: [], draft: null };
let updateTimer = null;
let confirmAction = null;

// ------------------------------------------------------------------
// Daftar billboard
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
    const items = state.list.filter((b) => !q || b.label.toLowerCase().includes(q) || String(b.id) === q);
    const list = $('list');
    list.replaceChildren();

    if (!items.length) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = state.list.length ? 'Tidak ada yang cocok' : 'Belum ada billboard';
        list.appendChild(empty);
        return;
    }

    for (const b of items) {
        const el = document.createElement('div');
        el.className = 'item' + (b.active ? '' : ' off');

        const top = document.createElement('div');
        top.className = 'top';
        const name = document.createElement('div');
        name.className = 'name';
        name.textContent = b.label; // textContent: aman dari HTML injection
        const id = document.createElement('div');
        id.className = 'meta';
        id.textContent = '#' + b.id;
        top.append(name, id);

        const meta = document.createElement('div');
        meta.className = 'meta';
        meta.textContent = [
            b.type === 'prop' ? 'Prop' : 'Zone',
            MEDIA_LABEL[b.mediaType] || 'URL tidak valid',
            b.dist + ' m',
            b.active ? 'Aktif' : 'Mati',
        ].join(' · ');

        const btns = document.createElement('div');
        btns.className = 'btns';
        btns.append(
            button('Edit', 'primary', () => openForm('edit', { id: b.id })),
            button('Teleport', '', () => post('teleport', { id: b.id })),
            button(b.active ? 'Matikan' : 'Nyalakan', '', () => post('toggle', { id: b.id })),
            button('Hapus', 'danger', () => askConfirm(`Hapus billboard "${b.label}" (#${b.id})?`, () => post('delete', { id: b.id }))),
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
    if (view === 'list') $('title').textContent = 'Billboard';
}

function toast(text) {
    const t = $('toast');
    t.textContent = text;
    t.style.display = 'block';
}

function setType(type) {
    document.querySelectorAll('#seg-type button').forEach((b) => b.classList.toggle('on', b.dataset.type === type));
    document.querySelectorAll('.only-prop').forEach((e) => e.classList.toggle('hidden', type !== 'prop'));
    document.querySelectorAll('.only-zone').forEach((e) => e.classList.toggle('hidden', type !== 'zone'));
}

function setBadge(d) {
    const badge = $('badge');
    if (!d.url) {
        badge.className = 'badge';
        badge.textContent = '';
    } else if (d.mediaType) {
        badge.className = 'badge ok';
        badge.textContent = MEDIA_LABEL[d.mediaType];
    } else {
        badge.className = 'badge bad';
        badge.textContent = 'Tidak valid';
    }
}

function fillForm(d) {
    state.draft = d;
    $('title').textContent = d.id ? `Edit Billboard #${d.id}` : 'Billboard Baru';
    for (const el of fields) {
        const v = d[el.dataset.f];
        if (el.type === 'checkbox') el.checked = !!v;
        else el.value = v ?? '';
    }
    setType(d.type);
    setBadge(d);
    updateRangeLabels();
}

function readForm() {
    const data = { type: state.draft.type };
    for (const el of fields) {
        const k = el.dataset.f;
        if (el.type === 'checkbox') data[k] = el.checked;
        else if (el.type === 'number' || el.type === 'range') data[k] = parseFloat(el.value);
        else data[k] = el.value;
    }
    return data;
}

function updateRangeLabels() {
    $('val-renderDistance').textContent = document.querySelector('[data-f=renderDistance]').value;
    $('val-brightness').textContent = document.querySelector('[data-f=brightness]').value;
}

// Kirim perubahan ke client (preview langsung di game)
function sendUpdate(refill) {
    clearTimeout(updateTimer);
    updateTimer = setTimeout(async () => {
        if (!state.draft) return;
        const d = await post('update', readForm());
        if (!d) return;
        if (refill) fillForm(d); // ganti tipe/model: ukuran & offset ikut preset
        else {
            state.draft = d;
            setBadge(d);
        }
    }, refill ? 0 : 150);
}

async function openForm(kind, data) {
    const d = await post(kind, data);
    if (!d) return;
    fillForm(d);
    showView('form');
}

fields.forEach((el) => {
    const refill = el.dataset.f === 'model';
    el.addEventListener('input', () => {
        updateRangeLabels();
        sendUpdate(refill);
    });
});

document.querySelectorAll('#seg-type button').forEach((b) => {
    b.onclick = () => {
        if (!state.draft || state.draft.type === b.dataset.type) return;
        state.draft.type = b.dataset.type;
        setType(b.dataset.type);
        sendUpdate(true);
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
    if (!state.draft.mediaType) return toast('URL media belum valid.');
    const btn = $('btn-save');
    btn.disabled = true;
    const res = await post('save');
    btn.disabled = false;
    if (res && res.ok) {
        state.draft = null;
        state.list = res.list || state.list;
        renderList();
        showView('list');
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

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'open': {
            state.list = data.list || [];
            state.presets = data.presets || [];
            state.draft = null;

            const sel = $('sel-model');
            sel.replaceChildren();
            for (const p of state.presets) {
                const o = document.createElement('option');
                o.value = p.model;
                o.textContent = `${p.label} (${p.model})`;
                sel.appendChild(o);
            }

            const lim = data.limits;
            const rd = document.querySelector('[data-f=renderDistance]');
            rd.min = lim.minRender;
            rd.max = lim.maxRender;
            document.querySelectorAll('[data-f=width],[data-f=height]').forEach((e) => (e.max = lim.maxSize));

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
