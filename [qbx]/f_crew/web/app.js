// Crew app (f_phone custom app). Vanilla JS, tanpa framework. Semua teks dari server dirender
// lewat textContent (h()), jadi aman dari injeksi HTML.
(() => {
    'use strict';

    const $app = document.getElementById('app');
    const $stage = document.getElementById('stage');

    // Tinggi layar HP dalam satuan layout HP (f_phone & f_phone sama-sama 956). Iframe app
    // pihak ketiga tidak ikut di-zoom bersama bingkai HP, jadi isinya ditata di ukuran piksel
    // asli dan terlihat jauh lebih besar dari aplikasi bawaan. Skala = tinggi iframe / 956
    // mengembalikannya ke ukuran yang sama; bila iframe sudah ikut di-zoom, skalanya 1.
    const PHONE_H = 956;
    // Desain dasar Crew lebih rapat dari aplikasi bawaan HP (mis. ikon tab 24 vs 33 px), jadi
    // seluruh tampilan diperbesar sekian kali supaya setara. Naikkan/turunkan di sini saja.
    const UI_SCALE = 1.2;
    function fitStage() {
        const k = Math.min(2, Math.max(0.3, (window.innerHeight / PHONE_H) * UI_SCALE));
        $stage.style.width = `${window.innerWidth / k}px`;
        $stage.style.height = `${window.innerHeight / k}px`;
        $stage.style.transform = k === 1 ? '' : `scale(${k})`;
    }
    fitStage();
    window.addEventListener('resize', fitStage);
    const RES = () => globalThis.resourceName || 'f_crew';

    const RECRUIT = { open: ['Terbuka', 'green'], apply: ['Lamaran', 'yellow'], closed: ['Tertutup', 'red'] };
    const TAG = { gang: 'Gang', community: 'Komunitas' };
    const COLORS = ['#8e44ad', '#c0392b', '#e67e22', '#f1c40f', '#27ae60', '#16a085', '#2980b9', '#34495e', '#7f8c8d', '#d35400', '#e84393', '#2d3436'];
    const LIMITS = { name: 24, desc: 140, msg: 140, announce: 300, grade: 16, minMembers: 5, maxMembers: 50 };

    const ICONS = {
        discover: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>',
        create: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/></svg>',
        status: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 5h16v14H4z"/><path d="m4 7 8 6 8-6"/></svg>',
        home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3 20 7v6c0 4.5-3.4 7.4-8 8-4.6-.6-8-3.5-8-8V7z"/></svg>',
        members: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.6-3.6 3.2-5.5 6.5-5.5s5.9 1.9 6.5 5.5"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.8c2 .7 3.2 2.4 3.5 5.2"/></svg>',
        board: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M7 21V11M12 21V4M17 21v-7"/></svg>',
        bank: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M7 15h3"/></svg>',
        manage: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>',
    };

    const S = { state: null, tab: null, filter: 'all', search: '', stale: false };

    // ---------------------------------------------------------------- helpers

    function h(tag, props, ...kids) {
        const el = document.createElement(tag);
        if (props) {
            for (const [k, v] of Object.entries(props)) {
                if (v == null || v === false) continue;
                if (k === 'class') el.className = v;
                else if (k === 'vars') for (const [n, c] of Object.entries(v)) el.style.setProperty(n, c);
                else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
                else if (k === 'value') el.value = v;
                else el.setAttribute(k, v === true ? '' : v);
            }
        }
        for (const kid of kids.flat()) {
            if (kid == null || kid === false) continue;
            el.append(kid instanceof Node ? kid : document.createTextNode(String(kid)));
        }
        return el;
    }

    function icon(name) {
        const span = document.createElement('span');
        span.innerHTML = ICONS[name]; // konstanta statis, bukan data pemain
        return span.firstChild;
    }

    const fmtMoney = (n) => 'Rp ' + new Intl.NumberFormat('id-ID').format(n || 0);
    const initials = (s) => (s || '?').replace(/[^A-Za-z0-9 ]/g, '').split(' ').filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase() || '?';
    const hexAlpha = (hex, a) => (/^#[0-9a-f]{6}$/i.test(hex) ? hex + a : 'transparent');

    function ago(ts) {
        if (!ts) return '';
        const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
        if (s < 60) return 'baru saja';
        if (s < 3600) return Math.floor(s / 60) + ' mnt lalu';
        if (s < 86400) return Math.floor(s / 3600) + ' jam lalu';
        return Math.floor(s / 86400) + ' hari lalu';
    }

    async function call(action, payload) {
        let res;
        try {
            if (typeof globalThis.fetchNuiStrict === 'function') {
                res = await globalThis.fetchNuiStrict('call', { action, payload });
            } else {
                const r = await fetch(`https://${RES()}/call`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                    body: JSON.stringify({ action, payload }),
                });
                res = await r.json();
            }
        } catch (e) {
            res = null;
        }
        return res || { ok: false, err: 'Tidak bisa terhubung ke server.' };
    }

    /** Hasil aksi tampil sebagai notifikasi HP (banner f_phone), bukan toast di dalam app. */
    function toast(msg) {
        if (!msg) return;
        const body = { msg: String(msg) };
        try {
            if (typeof globalThis.fetchNuiStrict === 'function') {
                globalThis.fetchNuiStrict('notify', body).catch(() => {});
            } else {
                fetch(`https://${RES()}/notify`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                    body: JSON.stringify(body),
                }).catch(() => {});
            }
        } catch (e) { /* tidak ada NUI */ }
    }

    /** Jalankan aksi tulis dengan tombol dikunci, tampilkan hasil. Return data atau undefined. */
    async function act(btn, action, payload, okMsg) {
        if (btn) btn.disabled = true;
        const res = await call(action, payload);
        if (btn) btn.disabled = false;
        if (!res.ok) {
            toast(res.err || 'Gagal.', 'err');
            return undefined;
        }
        if (okMsg) toast(okMsg, 'ok');
        return res.data === undefined ? true : res.data;
    }

    function sheet(build, onClose) {
        const overlay = h('div', { class: 'overlay' });
        const panel = h('div', { class: 'sheet' }, h('div', { class: 'grip' }));
        const close = () => {
            if (!overlay.isConnected) return;
            overlay.remove();
            if (onClose) onClose();
        };
        overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
        overlay.append(panel);
        build(panel, close);
        $stage.append(overlay);
        return close;
    }

    function confirmBox(title, desc, okText, danger) {
        return new Promise((resolve) => {
            let answer = false;
            sheet((p, close) => {
                p.append(
                    h('h3', { class: 'center' }, title),
                    desc ? h('p', { class: 'muted small center', style: 'margin:6px 0 16px' }, desc) : null,
                    h('div', { class: 'btns' },
                        h('button', { class: 'btn gray', onclick: close }, 'Batal'),
                        h('button', { class: 'btn ' + (danger ? 'red' : ''), onclick: () => { answer = true; close(); } }, okText || 'Ya'),
                    ),
                );
            }, () => resolve(answer));
        });
    }

    function seg(options, value, onChange) {
        const wrap = h('div', { class: 'seg' });
        const draw = (v) => {
            wrap.replaceChildren(...options.map(([val, label]) =>
                h('button', { class: val === v ? 'on' : '', type: 'button', onclick: () => { draw(val); onChange(val); } }, label)));
        };
        draw(value);
        return wrap;
    }

    function swatches(value, onChange) {
        const wrap = h('div', { class: 'swatches' });
        const draw = (v) => {
            wrap.replaceChildren(...COLORS.map((c) =>
                h('button', { class: 'swatch' + (c === v ? ' on' : ''), type: 'button', vars: { '--c': c }, onclick: () => { draw(c); onChange(c); } })));
        };
        draw(value);
        return wrap;
    }

    const title = (text) => h('h1', { class: 'title' }, text);
    const section = (text) => h('div', { class: 'section' }, text);
    const loading = () => h('div', { class: 'loading', style: 'padding:40px 0' }, h('div', { class: 'spinner' }));

    function recruitPill(r) {
        const [label, color] = RECRUIT[r] || RECRUIT.apply;
        return h('span', { class: 'pill ' + color }, label);
    }

    // ---------------------------------------------------------------- state & render

    async function refresh() {
        const res = await call('state');
        if (!res.ok) {
            $app.replaceChildren(h('div', { class: 'content' }, h('div', { class: 'empty' }, res.err || 'Gagal memuat.')));
            return;
        }
        S.state = res.data;
        S.stale = false;
        if (res.data.open === 'turf') { S.tab = 'board'; S.boardMode = 'turf'; }
        render();
    }

    function tabsFor(st) {
        if (st.gang) {
            const g = st.gang;
            const tabs = [
                { id: 'home', label: 'Beranda' },
                { id: 'members', label: 'Anggota' },
                { id: 'board', label: 'Peringkat' },
                { id: 'bank', label: 'Kas' },
            ];
            if (g.perms.deputy) tabs.push({ id: 'manage', label: 'Kelola', badge: g.pending || 0 });
            return tabs;
        }
        return [
            { id: 'discover', label: 'Jelajah' },
            { id: 'board', label: 'Peringkat' },
            { id: 'create', label: 'Buat' },
            { id: 'status', label: 'Status', badge: st.invites ? st.invites.length : 0 },
        ];
    }

    function render() {
        const st = S.state;
        $app.replaceChildren();
        if (st.foreign) {
            $app.append(h('main', { class: 'content' }, title('Crew'),
                h('div', { class: 'note' }, 'Kamu tergabung di gang lain di luar aplikasi Crew. Keluar dulu dari gang itu untuk memakai Crew.')));
            return;
        }
        const tabs = tabsFor(st);
        if (!tabs.some((t) => t.id === S.tab)) S.tab = tabs[0].id;
        const content = h('main', { class: 'content' });
        const bar = h('nav', { class: 'tabbar' }, tabs.map((t) =>
            h('button', {
                class: 'tab' + (t.id === S.tab ? ' on' : ''),
                onclick: () => { if (S.tab !== t.id) { S.tab = t.id; S.stale ? refresh() : render(); } },
            }, icon(t.id), t.label, t.badge ? h('span', { class: 'badge' }, t.badge) : null)));
        $app.append(content, bar);
        VIEWS[S.tab](content, st);
    }

    // ---------------------------------------------------------------- views: tanpa gang

    function gangRow(g, onclick) {
        return h('div', { class: 'gang', onclick },
            h('div', { class: 'avatar', vars: { '--c': g.color } }, initials(g.label)),
            h('div', { class: 'gang-body' },
                h('div', { class: 'gang-name' }, h('span', null, g.label), h('span', { class: 'pill tag' }, TAG[g.tag] || 'Gang')),
                g.description ? h('div', { class: 'gang-desc' }, g.description) : null,
                h('div', { class: 'meta' },
                    h('span', null, `${g.members}/${g.max} anggota`),
                    h('span', null, '·'),
                    h('span', null, h('span', { class: 'dot on' }), ` ${g.online} online`),
                    recruitPill(g.recruit)),
            ));
    }

    async function viewDiscover(el, st) {
        const list = h('div');
        const search = h('input', { class: 'search', placeholder: 'Cari nama gang', value: S.search, maxlength: 24 });
        const chips = h('div', { class: 'chips' });
        el.append(title('Jelajah'), search, chips, list);

        let data = [];
        const draw = () => {
            chips.replaceChildren(...[['all', 'Semua'], ['gang', 'Gang'], ['community', 'Komunitas']].map(([v, l]) =>
                h('button', { class: 'chip' + (S.filter === v ? ' on' : ''), onclick: () => { S.filter = v; draw(); } }, l)));
            const q = S.search.trim().toLowerCase();
            const shown = data.filter((g) => (S.filter === 'all' || g.tag === S.filter) && (!q || g.label.toLowerCase().includes(q)));
            if (!shown.length) {
                list.replaceChildren(h('div', { class: 'empty' }, data.length ? 'Tidak ada yang cocok.' : 'Belum ada gang. Jadilah yang pertama!'));
                return;
            }
            list.replaceChildren(h('div', { class: 'card' }, shown.map((g) => gangRow(g, () => openGang(g, st)))));
        };
        search.addEventListener('input', () => { S.search = search.value; draw(); });

        list.append(loading());
        const res = await call('discover');
        if (!res.ok) { list.replaceChildren(h('div', { class: 'empty' }, res.err)); return; }
        data = res.data || [];
        draw();
    }

    function openGang(g, st) {
        sheet((p, close) => {
            p.append(
                h('div', { class: 'center' },
                    h('div', { class: 'avatar big', vars: { '--c': g.color }, style: 'margin:4px auto 10px' }, initials(g.label)),
                    h('h2', null, g.label),
                    h('div', { class: 'meta', style: 'justify-content:center;margin:6px 0 12px' },
                        h('span', { class: 'pill tag' }, TAG[g.tag] || 'Gang'), recruitPill(g.recruit))),
                g.description ? h('p', { class: 'card pad announce', style: 'margin-bottom:10px' }, g.description) : null,
                h('div', { class: 'card stats', style: 'border-top:0;margin-bottom:14px' },
                    h('div', { class: 'stat' }, h('b', null, g.members), h('small', null, 'Anggota')),
                    h('div', { class: 'stat' }, h('b', null, g.max), h('small', null, 'Maksimal')),
                    h('div', { class: 'stat' }, h('b', null, g.online), h('small', null, 'Online'))),
            );

            const box = h('div', { class: 'stack' });
            p.append(box);
            if (st.cooldown > 0) {
                box.append(h('div', { class: 'note warn' }, `Kamu baru keluar dari gang. Tunggu ${Math.ceil(st.cooldown / 3600)} jam lagi.`));
            } else if (st.application) {
                box.append(h('div', { class: 'note' }, st.application.name === g.name
                    ? 'Lamaranmu ke gang ini sedang ditinjau.'
                    : `Kamu masih menunggu keputusan lamaran ke ${st.application.label}.`));
            } else if (g.members >= g.max) {
                box.append(h('div', { class: 'note' }, 'Gang ini sudah penuh.'));
            } else if (g.recruit === 'closed') {
                box.append(h('div', { class: 'note' }, 'Gang ini hanya menerima anggota lewat undangan.'));
            } else if (g.recruit === 'open') {
                const btn = h('button', { class: 'btn' }, 'Gabung Sekarang');
                btn.onclick = async () => {
                    if (await act(btn, 'apply', { gang: g.name }, 'Kamu bergabung ke ' + g.label)) { close(); S.tab = 'home'; refresh(); }
                };
                box.append(btn);
            } else {
                const msg = h('textarea', { class: 'input', placeholder: 'Pesan untuk boss (opsional)', maxlength: LIMITS.msg });
                const btn = h('button', { class: 'btn' }, 'Kirim Lamaran');
                btn.onclick = async () => {
                    if (await act(btn, 'apply', { gang: g.name, message: msg.value }, 'Lamaran terkirim')) { close(); S.tab = 'status'; refresh(); }
                };
                box.append(msg, btn, h('p', { class: 'muted small center' }, 'Kamu hanya bisa punya 1 lamaran aktif sampai ada keputusan.'));
            }
        });
    }

    function viewCreate(el, st) {
        el.append(title('Buat Gang'));
        if (st.cooldown > 0) {
            el.append(h('div', { class: 'note warn' }, `Kamu baru keluar dari gang. Tunggu ${Math.ceil(st.cooldown / 3600)} jam lagi sebelum membuat gang.`));
            return;
        }
        const f = { tag: 'gang', recruit: 'apply', color: COLORS[0] };
        const name = h('input', { class: 'input', placeholder: 'Nama gang', maxlength: LIMITS.name });
        const desc = h('textarea', { class: 'input', placeholder: 'Deskripsi singkat', maxlength: LIMITS.desc });
        const btn = h('button', { class: 'btn', style: 'margin-top:18px' }, 'Buat Gang');
        btn.onclick = async () => {
            const ok = await act(btn, 'create', { label: name.value, description: desc.value, tag: f.tag, recruit: f.recruit, color: f.color }, 'Gang berhasil dibuat!');
            if (ok) { S.tab = 'home'; refresh(); }
        };
        el.append(
            h('label', { class: 'field' }, 'Nama'), name,
            h('label', { class: 'field' }, 'Jenis'), seg([['gang', 'Gang'], ['community', 'Komunitas']], f.tag, (v) => { f.tag = v; }),
            h('label', { class: 'field' }, 'Deskripsi'), desc,
            h('label', { class: 'field' }, 'Warna'), swatches(f.color, (v) => { f.color = v; }),
            h('label', { class: 'field' }, 'Penerimaan anggota'),
            seg([['open', 'Terbuka'], ['apply', 'Lamaran'], ['closed', 'Undangan']], f.recruit, (v) => { f.recruit = v; }),
            btn,
            h('p', { class: 'muted small center', style: 'margin-top:10px' }, 'Gratis. Kamu otomatis menjadi Boss. Nama gang tidak bisa diubah.'),
        );
    }

    function viewStatus(el, st) {
        el.append(title('Status'));
        if (st.cooldown > 0) {
            el.append(h('div', { class: 'note warn', style: 'margin-bottom:10px' }, `Cooldown: ${Math.ceil(st.cooldown / 3600)} jam lagi sebelum bisa buat atau gabung gang.`));
        }
        el.append(section('Lamaran saya'));
        if (st.application) {
            const a = st.application;
            const cancel = h('button', { class: 'mini red' }, 'Batalkan');
            cancel.onclick = async () => {
                if (!(await confirmBox('Batalkan lamaran?', `Lamaran ke ${a.label} akan dihapus.`, 'Batalkan', true))) return;
                if (await act(cancel, 'cancelApply', {}, 'Lamaran dibatalkan')) refresh();
            };
            el.append(h('div', { class: 'card' },
                h('div', { class: 'row' },
                    h('div', { class: 'avatar', vars: { '--c': a.color } }, initials(a.label)),
                    h('div', { class: 'grow' }, h('div', { class: 'name' }, a.label), h('div', { class: 'small muted' }, 'Menunggu keputusan · ' + ago(a.at))),
                    cancel)));
        } else {
            el.append(h('div', { class: 'card pad muted small' }, 'Tidak ada lamaran aktif.'));
        }

        el.append(section('Undangan'));
        if (!st.invites || !st.invites.length) {
            el.append(h('div', { class: 'card pad muted small' }, 'Belum ada undangan.'));
            return;
        }
        el.append(h('div', { class: 'card' }, st.invites.map((inv) => {
            const yes = h('button', { class: 'mini green' }, 'Terima');
            const no = h('button', { class: 'mini red' }, 'Tolak');
            yes.onclick = async () => { if (await act(yes, 'acceptInvite', { id: inv.id }, 'Kamu bergabung ke ' + inv.label)) { S.tab = 'home'; refresh(); } };
            no.onclick = async () => { if (await act(no, 'declineInvite', { id: inv.id })) refresh(); };
            return h('div', { class: 'row' },
                h('div', { class: 'avatar', vars: { '--c': inv.color } }, initials(inv.label)),
                h('div', { class: 'grow' }, h('div', { class: 'name' }, inv.label), h('div', { class: 'small muted' }, `${inv.members}/${inv.max} anggota · ${ago(inv.at)}`)),
                no, yes);
        })));
    }

    // ---------------------------------------------------------------- views: anggota

    function viewHome(el, st) {
        const g = st.gang;
        el.append(title('Beranda'));
        el.append(h('div', { class: 'card' },
            h('div', { class: 'hero', vars: { '--c2': hexAlpha(g.color, '55') } },
                h('div', { class: 'avatar big', vars: { '--c': g.color } }, initials(g.label)),
                h('div', { class: 'grow' },
                    h('h2', null, g.label),
                    h('div', { class: 'meta', style: 'margin-top:4px' }, h('span', { class: 'pill tag' }, TAG[g.tag] || 'Gang'), recruitPill(g.recruit)),
                    h('div', { class: 'small muted', style: 'margin-top:6px' }, 'Rank kamu: ', h('b', { class: 'me' }, g.gradeName)))),
            h('div', { class: 'stats' },
                h('div', { class: 'stat' }, h('b', null, `${g.members}/${g.max}`), h('small', null, 'Anggota')),
                h('div', { class: 'stat' }, h('b', null, g.online), h('small', null, 'Online')),
                h('div', { class: 'stat' }, h('b', null, g.radio || '-'), h('small', null, 'Radio')))));

        if (g.description) el.append(h('p', { class: 'muted small', style: 'margin:10px 4px 0' }, g.description));

        el.append(section('Pengumuman'));
        el.append(g.announcement
            ? h('div', { class: 'card pad' }, h('div', { class: 'announce' }, g.announcement), h('div', { class: 'small muted', style: 'margin-top:8px' }, ago(g.announcedAt)))
            : h('div', { class: 'card pad muted small' }, 'Belum ada pengumuman.'));

        el.append(section('Garasi gang'));
        if (g.hasGarage) {
            const gps = h('button', { class: 'mini' }, 'Tandai di GPS');
            gps.onclick = () => act(gps, 'gps', {}, 'Lokasi garasi ditandai di GPS');
            el.append(h('div', { class: 'card' }, h('div', { class: 'row' },
                h('div', { class: 'grow' }, h('div', { class: 'name' }, 'Garasi ' + g.label), h('div', { class: 'small muted' }, 'Hanya kendaraan milikmu yang terlihat')),
                gps)));
        } else {
            el.append(h('div', { class: 'card pad muted small' }, g.perms.boss ? 'Belum ada garasi. Atur di menu Kelola.' : 'Gang belum punya garasi.'));
        }

        if (g.radio) {
            el.append(h('p', { class: 'muted small', style: 'margin:10px 4px 0' }, `Channel radio ${g.radio} khusus anggota gang.`));
        }

        if (!g.perms.boss) {
            const leave = h('button', { class: 'btn line', style: 'margin-top:26px' }, 'Keluar dari Gang');
            leave.onclick = async () => {
                if (!(await confirmBox('Keluar dari gang?', 'Kamu harus menunggu 24 jam sebelum bisa gabung atau buat gang lagi.', 'Keluar', true))) return;
                if (await act(leave, 'leave', {}, 'Kamu keluar dari gang')) { S.tab = null; refresh(); }
            };
            el.append(leave);
        }
    }

    async function viewMembers(el, st) {
        const g = st.gang;
        const box = h('div', null, loading());
        el.append(title('Anggota'), box);
        const res = await call('members');
        if (!res.ok) { box.replaceChildren(h('div', { class: 'empty' }, res.err)); return; }
        const { list, grades, myGrade } = res.data;
        const online = list.filter((m) => m.online).length;
        box.replaceChildren(
            h('p', { class: 'muted small', style: 'margin:0 4px 10px' }, `${list.length}/${g.max} anggota · ${online} online`),
            h('div', { class: 'card' }, list.map((m) => h('div', {
                class: 'row' + (m.manage ? ' tap' : ''),
                onclick: m.manage ? () => memberSheet(m, grades, myGrade, g) : null,
            },
            h('span', { class: 'dot' + (m.online ? ' on' : '') }),
            h('div', { class: 'grow' }, h('div', { class: 'name' + (m.me ? ' me' : '') }, m.name + (m.me ? ' (kamu)' : ''))),
            h('span', { class: 'end' }, m.gradeName)))),
        );
    }

    function memberSheet(m, grades, myGrade, g) {
        sheet((p, close) => {
            p.append(h('h3', { class: 'center' }, m.name), h('p', { class: 'muted small center', style: 'margin:4px 0 14px' }, 'Rank sekarang: ' + m.gradeName));
            p.append(section('Ubah rank'));
            const opts = h('div', { class: 'card' });
            for (let gr = Math.min(myGrade - 1, 2); gr >= 0; gr--) {
                const cur = gr === m.grade;
                const b = h('div', { class: 'row' + (cur ? '' : ' tap') }, h('div', { class: 'grow' }, grades[gr]), cur ? h('span', { class: 'end' }, 'Sekarang') : null);
                if (!cur) {
                    b.onclick = async () => {
                        if (await act(null, 'setGrade', { cid: m.cid, grade: gr }, 'Rank diubah')) { close(); render(); }
                    };
                }
                opts.append(b);
            }
            p.append(opts);

            const kick = h('button', { class: 'btn red', style: 'margin-top:16px' }, 'Keluarkan dari Gang');
            kick.onclick = async () => {
                if (!(await confirmBox('Keluarkan ' + m.name + '?', 'Dia harus menunggu 24 jam sebelum bisa gabung gang lagi.', 'Keluarkan', true))) return;
                if (await act(kick, 'kick', { cid: m.cid }, m.name + ' dikeluarkan')) { close(); render(); }
            };
            p.append(kick);

            if (g.perms.boss) {
                const hand = h('button', { class: 'btn gray', style: 'margin-top:8px' }, 'Jadikan Boss');
                hand.onclick = async () => {
                    if (!(await confirmBox('Serahkan kepemimpinan?', `${m.name} akan menjadi Boss dan kamu turun menjadi ${grades[2]}.`, 'Serahkan', true))) return;
                    if (await act(hand, 'handover', { cid: m.cid }, 'Kepemimpinan diserahkan')) { close(); refresh(); }
                };
                p.append(hand);
            }
        });
    }

    function viewBoard(el, st) {
        el.append(title('Peringkat'));
        const body = h('div');
        const modes = st.gang
            ? [['members', 'Anggota'], ['gangs', 'Antar Gang'], ['turf', 'Wilayah']]
            : [['gangs', 'Antar Gang'], ['turf', 'Wilayah']];
        const views = { members: boardMembers, gangs: boardGangs, turf: boardTurf };
        if (!modes.some(([v]) => v === S.boardMode)) S.boardMode = modes[0][0];
        el.append(seg(modes, S.boardMode, (v) => {
            S.boardMode = v;
            body.replaceChildren();
            views[v](body);
        }));
        el.append(body);
        views[S.boardMode](body);
    }

    async function boardTurf(el) {
        const box = h('div', null, loading());
        el.append(box);
        const res = await call('turfBoard');
        if (!res.ok) { box.replaceChildren(h('div', { class: 'empty' }, res.err)); return; }
        const { list, wars, total, enabled } = res.data;
        box.replaceChildren(h('p', { class: 'muted small', style: 'margin:10px 4px' },
            `${total} zona di kota. Berada 1 menit di zona gang lain atau zona bebas, lalu tekan J untuk merebutnya. Saat perebutan, poin didapat dari bertahan di zona, mengalahkan gang lain, jual narkoba, dan curi mobil. Hanya gang bertag Gang yang ikut.`));
        if (!enabled) { box.append(h('div', { class: 'note' }, 'Perebutan wilayah sedang dimatikan.')); return; }
        if (wars.length) {
            box.append(section('Sedang Diperebutkan'), h('div', { class: 'card' }, wars.map((w) => h('div', { class: 'row' },
                h('div', { class: 'grow' }, h('div', { class: 'name' }, w.label)),
                h('span', { class: 'end', style: 'color:var(--red)' }, `${Math.ceil(w.left / 60)} mnt lagi`)))));
        }
        box.append(section('Penguasa Wilayah'));
        box.append(list.length
            ? h('div', { class: 'card' }, list.map((r) => h('div', { class: 'row' },
                h('span', { class: 'rank' + (r.rank <= 3 ? ' top' : '') }, r.rank),
                h('div', { class: 'avatar', vars: { '--c': r.color }, style: 'width:34px;height:34px;font-size:18px;border-radius:9px' }, initials(r.label)),
                h('div', { class: 'grow' },
                    h('div', { class: 'name' + (r.mine ? ' me' : '') }, r.label),
                    h('div', { class: 'small muted' }, r.zones)),
                h('span', { class: 'end' }, `${r.count} zona`))))
            : h('div', { class: 'empty' }, 'Belum ada gang yang menguasai wilayah.'));
    }

    function boardGangs(el) {
        if (!S.boardTag) S.boardTag = (S.state.gang && S.state.gang.tag) || 'gang';
        const box = h('div');
        const load = async () => {
            box.replaceChildren(loading());
            const res = await call('gangBoard', { tag: S.boardTag });
            if (!res.ok) { box.replaceChildren(h('div', { class: 'empty' }, res.err)); return; }
            const list = res.data || [];
            box.replaceChildren(list.length
                ? h('div', { class: 'card' }, list.map((r) => h('div', { class: 'row' },
                    h('span', { class: 'rank' + (r.rank <= 3 ? ' top' : '') }, r.rank),
                    h('div', { class: 'avatar', vars: { '--c': r.color }, style: 'width:34px;height:34px;font-size:18px;border-radius:9px' }, initials(r.label)),
                    h('div', { class: 'grow' }, h('div', { class: 'name' + (r.mine ? ' me' : '') }, r.label)),
                    h('span', { class: 'end' }, `${r.points} poin`))))
                : h('div', { class: 'empty' }, S.boardTag === 'community' ? 'Belum ada komunitas.' : 'Belum ada gang.'));
        };
        const chips = h('div', { class: 'chips' });
        const drawChips = () => chips.replaceChildren(...[['gang', 'Gang'], ['community', 'Komunitas']].map(([v, l]) =>
            h('button', { class: 'chip' + (S.boardTag === v ? ' on' : ''), onclick: () => { if (S.boardTag !== v) { S.boardTag = v; drawChips(); load(); } } }, l)));
        drawChips();
        el.append(chips, h('p', { class: 'muted small', style: 'margin:0 4px 10px' }, 'Total waktu main seluruh anggota. 1 poin = 1 menit.'), box);
        load();
    }

    async function boardMembers(el) {
        const box = h('div', null, loading());
        el.append(h('p', { class: 'muted small', style: 'margin:10px 4px' }, 'Waktu main di kota selama menjadi anggota. 1 poin = 1 menit.'), box);
        const res = await call('leaderboard');
        if (!res.ok) { box.replaceChildren(h('div', { class: 'empty' }, res.err)); return; }
        const { list, boss } = res.data;
        box.replaceChildren(list.length
            ? h('div', { class: 'card' }, list.map((r) => h('div', { class: 'row' },
                h('span', { class: 'rank' + (r.rank <= 3 ? ' top' : '') }, r.rank),
                h('div', { class: 'grow' }, h('div', { class: 'name' + (r.me ? ' me' : '') }, r.name), r.online ? h('div', { class: 'small', style: 'color:var(--green)' }, 'Sedang online') : null),
                h('span', { class: 'end' }, `${r.points} poin`))))
            : h('div', { class: 'empty' }, 'Belum ada data.'));
        if (boss) {
            const reset = h('button', { class: 'btn line', style: 'margin-top:18px' }, 'Reset Peringkat Anggota');
            reset.onclick = async () => {
                if (!(await confirmBox('Reset peringkat anggota?', 'Semua poin anggota kembali ke 0. Total gang di peringkat antar gang tidak berubah.', 'Reset', true))) return;
                if (await act(reset, 'resetLeaderboard', {}, 'Peringkat direset')) render();
            };
            box.append(reset);
        }
    }

    async function viewBank(el) {
        const box = h('div', null, loading());
        el.append(title('Kas Gang'), box);
        const res = await call('bank');
        if (!res.ok) { box.replaceChildren(h('div', { class: 'empty' }, res.err)); return; }
        const { balance, log, canManage } = res.data;
        box.replaceChildren();
        if (balance == null) {
            box.append(h('div', { class: 'note warn' }, 'Kas gang belum tersedia. Hubungi admin.'));
            return;
        }
        box.append(h('div', { class: 'card pad' }, h('div', { class: 'small muted' }, 'Saldo'), h('div', { class: 'money' }, fmtMoney(balance))));

        const amountInput = () => h('input', { class: 'input', type: 'number', min: 1, placeholder: 'Jumlah ($)', inputmode: 'numeric' });
        const form = h('div', { class: 'stack', style: 'margin-top:12px' });
        const openForm = (kind) => {
            form.replaceChildren();
            const amount = amountInput();
            const number = kind === 'transfer' ? h('input', { class: 'input', placeholder: 'Nomor HP penerima', inputmode: 'numeric', maxlength: 20 }) : null;
            const labels = { deposit: ['Setor dari bank kamu', 'Setor', 'Setoran berhasil'], withdraw: ['Tarik ke bank kamu', 'Tarik', 'Penarikan berhasil'], transfer: ['Transfer ke rekening pemain', 'Kirim', 'Transfer berhasil'] };
            const [hint, btnText, okMsg] = labels[kind];
            const go = h('button', { class: 'btn' }, btnText);
            go.onclick = async () => {
                const payload = { amount: Number(amount.value) };
                if (number) payload.number = number.value;
                if (kind !== 'deposit' && !(await confirmBox(btnText + ' ' + fmtMoney(payload.amount) + '?', number ? 'Ke nomor ' + number.value : 'Dari kas gang', btnText))) return;
                if (await act(go, kind, payload, okMsg)) render();
            };
            form.append(h('div', { class: 'small muted' }, hint), number, amount, h('div', { class: 'btns' }, h('button', { class: 'btn gray', onclick: () => form.replaceChildren() }, 'Batal'), go));
        };
        const buttons = [h('button', { class: 'btn', onclick: () => openForm('deposit') }, 'Setor')];
        if (canManage) {
            buttons.push(h('button', { class: 'btn gray', onclick: () => openForm('withdraw') }, 'Tarik'));
            buttons.push(h('button', { class: 'btn gray', onclick: () => openForm('transfer') }, 'Transfer'));
        }
        box.append(h('div', { class: 'btns', style: 'margin-top:12px' }, buttons), form);

        box.append(section('Riwayat'));
        const KIND = { deposit: ['Setor', '+', 'var(--green)'], withdraw: ['Tarik', '-', 'var(--red)'], transfer: ['Transfer', '-', 'var(--red)'] };
        box.append(log.length
            ? h('div', { class: 'card' }, log.map((r) => {
                const [label, sign, color] = KIND[r.kind] || [r.kind, '', 'inherit'];
                return h('div', { class: 'row' },
                    h('div', { class: 'grow' }, h('div', { class: 'name' }, `${label} · ${r.name}`), h('div', { class: 'small muted' }, (r.note ? r.note + ' · ' : '') + ago(r.at))),
                    h('b', { style: 'color:' + color }, sign + fmtMoney(r.amount)));
            }))
            : h('div', { class: 'card pad muted small' }, 'Belum ada transaksi.'));
    }

    async function viewManage(el, st) {
        const g = st.gang;
        el.append(title('Kelola'));

        // Lamaran
        el.append(section('Lamaran masuk'));
        const apps = h('div', null, loading());
        el.append(apps);
        call('applications').then((res) => {
            if (!res.ok) { apps.replaceChildren(h('div', { class: 'card pad muted small' }, res.err)); return; }
            if (!res.data.length) { apps.replaceChildren(h('div', { class: 'card pad muted small' }, 'Tidak ada lamaran.')); return; }
            apps.replaceChildren(h('div', { class: 'card' }, res.data.map((a) => {
                const yes = h('button', { class: 'mini green' }, 'Terima');
                const no = h('button', { class: 'mini red' }, 'Tolak');
                yes.onclick = async () => { if (await act(yes, 'decide', { id: a.id, accept: true }, a.name + ' diterima')) refresh(); };
                no.onclick = async () => { if (await act(no, 'decide', { id: a.id, accept: false }, 'Lamaran ditolak')) refresh(); };
                return h('div', { class: 'row' },
                    h('div', { class: 'grow' }, h('div', { class: 'name' }, a.name), h('div', { class: 'small muted' }, (a.message ? '"' + a.message + '" · ' : '') + ago(a.at))),
                    no, yes);
            })));
        });

        // Undang
        el.append(section('Undang anggota'));
        const number = h('input', { class: 'input', placeholder: 'Nomor HP', inputmode: 'numeric', maxlength: 20 });
        const inv = h('button', { class: 'btn' }, 'Kirim Undangan');
        inv.onclick = async () => {
            const name = await act(inv, 'invite', { number: number.value });
            if (name) { toast('Undangan dikirim ke ' + name, 'ok'); number.value = ''; }
        };
        el.append(h('div', { class: 'card pad stack' }, number, inv));

        // Pengumuman
        el.append(section('Pengumuman'));
        const ann = h('textarea', { class: 'input', placeholder: 'Tulis pengumuman untuk semua anggota', maxlength: LIMITS.announce, value: g.announcement || '' });
        const annSave = h('button', { class: 'btn' }, 'Kirim');
        // pengumuman yang terkirim sudah masuk sebagai notifikasi HP ke semua anggota, pengirim juga
        annSave.onclick = async () => { if (await act(annSave, 'announce', { text: ann.value }, ann.value ? undefined : 'Pengumuman dihapus')) refresh(); };
        el.append(h('div', { class: 'card pad stack' }, ann, annSave, h('div', { class: 'small muted' }, 'Kosongkan lalu kirim untuk menghapus.')));

        if (!g.perms.boss) return;

        // Pengaturan
        el.append(section('Pengaturan gang'));
        const f = { tag: g.tag, recruit: g.recruit, color: g.color };
        const desc = h('textarea', { class: 'input', maxlength: LIMITS.desc, value: g.description || '' });
        const max = h('input', { class: 'input', type: 'number', min: Math.max(LIMITS.minMembers, g.members), max: LIMITS.maxMembers, value: g.max });
        const saveSet = h('button', { class: 'btn', style: 'margin-top:14px' }, 'Simpan Pengaturan');
        saveSet.onclick = async () => {
            if (await act(saveSet, 'settings', { description: desc.value, tag: f.tag, recruit: f.recruit, color: f.color, maxMembers: Number(max.value) }, 'Pengaturan disimpan')) refresh();
        };
        el.append(h('div', { class: 'card pad' },
            h('label', { class: 'field', style: 'margin-top:0' }, 'Deskripsi'), desc,
            h('label', { class: 'field' }, 'Jenis'), seg([['gang', 'Gang'], ['community', 'Komunitas']], f.tag, (v) => { f.tag = v; }),
            h('label', { class: 'field' }, 'Penerimaan anggota'), seg([['open', 'Terbuka'], ['apply', 'Lamaran'], ['closed', 'Undangan']], f.recruit, (v) => { f.recruit = v; }),
            h('label', { class: 'field' }, `Batas anggota (${LIMITS.minMembers}-${LIMITS.maxMembers})`), max,
            h('label', { class: 'field' }, 'Warna'), swatches(f.color, (v) => { f.color = v; }),
            saveSet));

        // Nama rank
        el.append(section('Nama rank'));
        const gradeInputs = [3, 2, 1, 0].map((i) => h('input', { class: 'input', maxlength: LIMITS.grade, value: g.grades[i] || '' }));
        const saveGr = h('button', { class: 'btn' }, 'Simpan Nama Rank');
        saveGr.onclick = async () => {
            const names = [gradeInputs[3].value, gradeInputs[2].value, gradeInputs[1].value, gradeInputs[0].value];
            if (await act(saveGr, 'renameGrades', { names }, 'Nama rank disimpan')) refresh();
        };
        const gradeHints = ['Boss', 'Wakil (kelola & kas)', 'Senior', 'Anggota'];
        el.append(h('div', { class: 'card pad stack' },
            gradeInputs.map((inp, idx) => h('div', null, h('div', { class: 'small muted', style: 'margin:0 2px 4px' }, gradeHints[idx]), inp)),
            saveGr));

        // Garasi
        el.append(section('Garasi gang'));
        const setG = h('button', { class: 'btn' }, g.hasGarage ? 'Pindahkan ke Lokasi Saya' : 'Jadikan Lokasi Saya Garasi');
        setG.onclick = async () => {
            if (!(await confirmBox('Atur garasi di sini?', 'Berdiri atau duduk di mobil tepat di titik garasi. Arah mobil jadi arah spawn.', 'Atur'))) return;
            if (await act(setG, 'setGarage', {}, 'Lokasi garasi disimpan')) refresh();
        };
        const garageCard = h('div', { class: 'card pad stack' },
            h('div', { class: 'small muted' }, g.hasGarage ? 'Garasi aktif. Tiap anggota hanya melihat kendaraannya sendiri.' : 'Belum ada garasi.'),
            setG);
        if (g.hasGarage) {
            const del = h('button', { class: 'btn line' }, 'Hapus Garasi');
            del.onclick = async () => {
                if (!(await confirmBox('Hapus garasi?', 'Kendaraan yang tersimpan tidak bisa diambil sampai garasi diatur lagi.', 'Hapus', true))) return;
                if (await act(del, 'removeGarage', {}, 'Garasi dihapus')) refresh();
            };
            garageCard.append(del);
        }
        el.append(garageCard);

        // Bubarkan
        el.append(section('Zona bahaya'));
        const confirmName = h('input', { class: 'input', placeholder: `Ketik "${g.label}" untuk konfirmasi` });
        const dis = h('button', { class: 'btn red' }, 'Bubarkan Gang');
        dis.onclick = async () => {
            if (!(await confirmBox('Bubarkan ' + g.label + '?', 'Semua anggota dikeluarkan, sisa kas masuk ke bank kamu, kendaraan di garasi gang dipindah ke impound. Tidak bisa dibatalkan.', 'Bubarkan', true))) return;
            if (await act(dis, 'disband', { confirm: confirmName.value }, 'Gang dibubarkan')) { S.tab = null; refresh(); }
        };
        el.append(h('div', { class: 'card pad stack' }, h('div', { class: 'small muted' }, 'Boss yang ingin keluar harus menyerahkan kepemimpinan (menu Anggota) atau membubarkan gang.'), confirmName, dis));
    }

    const VIEWS = {
        discover: viewDiscover,
        create: viewCreate,
        status: viewStatus,
        home: viewHome,
        members: viewMembers,
        board: viewBoard,
        bank: viewBank,
        manage: viewManage,
    };

    // ---------------------------------------------------------------- boot

    function applyTheme(settings) {
        const theme = settings && (settings.theme || (settings.display && settings.display.theme));
        document.body.classList.toggle('dark', theme !== 'light');
    }

    /** Push dari server: segarkan, kecuali pemain sedang mengetik (jangan hapus isiannya). */
    function onPush() {
        const a = document.activeElement;
        if (a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA') || document.querySelector('.overlay')) {
            S.stale = true;
            return;
        }
        refresh();
    }

    // ESC saat ada sheet terbuka: tutup sheet saja. Didaftarkan sebelum listener ESC milik f_phone
    // (dipasang setelah halaman selesai dimuat), jadi stopImmediatePropagation mencegah app ikut tertutup.
    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape') return;
        const all = document.querySelectorAll('.overlay');
        const overlay = all[all.length - 1]; // yang paling atas
        if (!overlay) {
            // app akan ditutup f_phone: kembalikan fokus keyboard ke HP supaya ESC berikutnya
            // (menutup HP dari homescreen) tidak tertahan di iframe yang sudah disembunyikan
            setTimeout(releaseFocus, 0);
            return;
        }
        e.preventDefault();
        e.stopImmediatePropagation();
        overlay.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });

    function releaseFocus() {
        const a = document.activeElement;
        if (a && typeof a.blur === 'function') a.blur();
        try { window.parent.focus(); } catch (err) { /* frame lain origin */ }
    }

    function start() {
        applyTheme(globalThis.settings);
        if (typeof globalThis.OnSettingsChange === 'function') globalThis.OnSettingsChange(applyTheme);
        if (typeof globalThis.onNuiEvent === 'function') globalThis.onNuiEvent('crew:refresh', onPush);
        if (typeof globalThis.OnAppOpen === 'function') globalThis.OnAppOpen(() => refresh());
        // ditutup lewat garis home / tombol lain: fokus juga dikembalikan ke HP
        if (typeof globalThis.OnAppClose === 'function') globalThis.OnAppClose(releaseFocus);
        refresh();
    }

    function whenReady() {
        return new Promise((resolve) => {
            if (globalThis.componentsLoaded) return resolve();
            const poll = setInterval(() => {
                if (globalThis.componentsLoaded) { clearInterval(poll); resolve(); }
            }, 50);
            addEventListener('message', (e) => {
                if (e.data === 'componentsLoaded') { clearInterval(poll); resolve(); }
            });
        });
    }

    whenReady().then(start);
})();
