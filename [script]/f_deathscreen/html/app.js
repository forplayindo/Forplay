(() => {
    'use strict';

    const $ = (id) => document.getElementById(id);
    const root = $('ds');
    const SVG_NS = 'http://www.w3.org/2000/svg';

    const ICONS = {
        shot: 'M11 2h2v3.1A7 7 0 0 1 18.9 11H22v2h-3.1A7 7 0 0 1 13 18.9V22h-2v-3.1A7 7 0 0 1 5.1 13H2v-2h3.1A7 7 0 0 1 11 5.1V2Zm1 5a5 5 0 1 0 0 10 5 5 0 0 0 0-10Zm0 3a2 2 0 1 1 0 4 2 2 0 0 1 0-4Z',
        melee: 'M7 6a2 2 0 0 1 4 0v1a2 2 0 0 1 3 0 2 2 0 0 1 3 1v5c0 4-3 7-6.5 7S5 17 5 14v-3a2 2 0 0 1 2-2V6Z',
        stabbed: 'M20 3 9.5 13.5l1 1L8 17l-3 4-2-2 4-3 2.5-2.5 1 1L21 4l-1-1Z',
        vehicle: 'M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11a2 2 0 0 1 2 2v4h-2v2h-3v-2H8v2H5v-2H3v-4a2 2 0 0 1 2-2Zm2.2 0h9.6l-1-3H8.2l-1 3ZM6.5 13a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3Zm11 0a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3Z',
        fall: 'M11 3h2v13.2l4.6-4.6L19 13l-7 7-7-7 1.4-1.4 4.6 4.6V3Z',
        drowned: 'M2 15c2 0 2-1.5 4-1.5S8 15 10 15s2-1.5 4-1.5 2 1.5 4 1.5 2-1.5 4-1.5V16c-2 0-2 1.5-4 1.5S16 16 14 16s-2 1.5-4 1.5S8 16 6 16s-2 1.5-4 1.5V15Zm0-5c2 0 2-1.5 4-1.5S8 10 10 10s2-1.5 4-1.5S16 10 18 10s2-1.5 4-1.5V11c-2 0-2 1.5-4 1.5S16 11 14 11s-2 1.5-4 1.5S8 11 6 11s-2 1.5-4 1.5V10Z',
        fire: 'M12 2s6 5 6 11a6 6 0 0 1-12 0c0-3 2-5 2-5s0 3 2 4c0-5 2-10 2-10Z',
        explosion: 'M12 2l2 5 5-2-2 5 5 2-5 2 2 5-5-2-2 5-2-5-5 2 2-5-5-2 5-2-2-5 5 2 2-5Z',
        animal: 'M8 10a2 2 0 1 1 0-4 2 2 0 0 1 0 4Zm8 0a2 2 0 1 1 0-4 2 2 0 0 1 0 4ZM5 14a2 2 0 1 1 0-4 2 2 0 0 1 0 4Zm14 0a2 2 0 1 1 0-4 2 2 0 0 1 0 4Zm-7-1c3 0 5 3 5 5a2.5 2.5 0 0 1-3 2.4c-1.3-.3-2.7-.3-4 0A2.5 2.5 0 0 1 7 18c0-2 2-5 5-5Z',
        bleeding: 'M12 2s7 7.6 7 12.5A7 7 0 0 1 5 14.5C5 9.6 12 2 12 2Z',
        electric: 'M13 2 4 14h7l-1 8 9-12h-7l1-8Z',
        gas: 'M7 18a5 5 0 0 1-.9-9.9A6 6 0 0 1 17.6 9 4.5 4.5 0 0 1 17.5 18H7Z',
        starved: 'M11 9H9V2H7v7H5V2H3v7c0 2.12 1.66 3.84 3.75 3.97V22h2.5v-9.03C11.34 12.84 13 11.12 13 9V2h-2v7Zm5-3v8h2.5v8H21V2c-2.76 0-5 2.24-5 4Z',
        dehydrated: 'M12 20a6 6 0 0 1-6-6c0-4 6-10.75 6-10.75S18 10 18 14a6 6 0 0 1-6 6Z',
        starvedDehydrated: 'M11 9H9V2H7v7H5V2H3v7c0 2.12 1.66 3.84 3.75 3.97V22h2.5v-9.03C11.34 12.84 13 11.12 13 9V2h-2v7Zm5-3v8h2.5v8H21V2c-2.76 0-5 2.24-5 4Z',
        unknown: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm1 15h-2v-2h2v2Zm1.1-6.6-.9.9c-.7.7-1.2 1.3-1.2 2.7h-2v-.5c0-1.1.5-2.1 1.2-2.8l1.2-1.3A2 2 0 1 0 10 8H8a4 4 0 1 1 6.1 2.4Z',
    };

    // titik tempel garis callout pada diagram (koordinat viewBox)
    const ANCHORS = {
        HEAD: [110, 30], NECK: [106, 70], SPINE: [100, 150], UPPER_BODY: [120, 105], LOWER_BODY: [120, 195],
        RARM: [44, 130], RHAND: [37, 212], RFINGER: [36, 232], RLEG: [76, 260], RFOOT: [78, 376],
        LARM: [156, 130], LHAND: [163, 212], LFINGER: [164, 232], LLEG: [124, 260], LFOOT: [122, 376],
    };

    // posisi kolom label callout (koordinat viewBox 310x420, tubuh ada di x 0-200)
    const LABEL_X = 214;
    const LINE_BEND_X = 198;
    const LABEL_GAP = 24;

    const HEART = 'M0 2.5C0 .5 2.5-.5 4 1.5 5.5-.5 8 .5 8 2.5 8 5 4 7.5 4 7.5S0 5 0 2.5Z';

    const st = {
        locale: null,
        deadline: 0,
        total: 300,
        ai: false, // dokter AI sedang menangani: countdown berhenti di server
        emsPaused: null, // detik tersisa saat EMS menangani (countdown dijeda), null = berjalan
        tick: null,
        toastTimer: null,
        cool: { dispatch: null, sync: null },
    };

    const t = (key, ...args) => {
        let s = (st.locale && st.locale.ui && st.locale.ui[key]) || key;
        args.forEach((a) => { s = s.replace(/%[sd]/, a); });
        return s;
    };

    const pad = (n) => String(n).padStart(2, '0');
    const fmt = (sec) => `${pad(Math.floor(sec / 60))}:${pad(sec % 60)}`;

    // ------------------------------------------------------------------ timer

    function setRemaining(sec) {
        st.deadline = Date.now() + Math.max(0, sec) * 1000;
        renderTimer();
    }

    function renderTimer() {
        if (st.ai) {
            $('timer').textContent = '--:--';
            $('timer-wrap').classList.remove('urgent');
            return;
        }
        const left = st.emsPaused !== null ? st.emsPaused : Math.max(0, Math.ceil((st.deadline - Date.now()) / 1000));
        $('timer').textContent = fmt(left);
        $('timer-wrap').classList.toggle('urgent', left > 0 && left <= 30);
        $('progress-bar').style.width = `${Math.min(100, (left / st.total) * 100)}%`;
        if (left === 0) $('subtitle').textContent = t('timeUp');
    }

    function startTick() {
        stopTick();
        st.tick = setInterval(renderTimer, 250);
    }

    function stopTick() {
        if (st.tick) clearInterval(st.tick);
        st.tick = null;
    }

    // ------------------------------------------------------------------ injuries

    function renderInjuries(injuries) {
        injuries = injuries || {};
        document.querySelectorAll('#body .zone').forEach((el) => {
            el.classList.remove('sev-1', 'sev-2', 'sev-3', 'sev-4');
            const sev = injuries[el.dataset.part];
            if (sev) el.classList.add(`sev-${Math.min(4, sev)}`);
        });

        const body = (st.locale && st.locale.body) || {};
        const sevLabels = (st.locale && st.locale.severity) || [];
        const list = Object.keys(injuries)
            .map((k) => ({ key: k, sev: Math.min(4, injuries[k]), label: body[k] || k }))
            .sort((a, b) => b.sev - a.sev);

        // callout (maks 3 luka terparah)
        const group = $('callouts');
        group.textContent = '';
        const top = list.slice(0, 3).filter((i) => ANCHORS[i.key])
            .sort((a, b) => ANCHORS[a.key][1] - ANCHORS[b.key][1]);
        let lastY = -Infinity;
        top.forEach((item) => {
            const [ax, ay] = ANCHORS[item.key];
            const ly = Math.max(ay - 14, lastY + LABEL_GAP, 12);
            lastY = ly;

            const line = document.createElementNS(SVG_NS, 'polyline');
            line.setAttribute('points', `${ax},${ay} ${LINE_BEND_X},${ly} ${LABEL_X - 4},${ly}`);
            group.appendChild(line);

            const dot = document.createElementNS(SVG_NS, 'circle');
            dot.setAttribute('class', 'anchor');
            dot.setAttribute('cx', ax);
            dot.setAttribute('cy', ay);
            dot.setAttribute('r', 2.2);
            group.appendChild(dot);

            const text = document.createElementNS(SVG_NS, 'text');
            text.setAttribute('x', LABEL_X);
            text.setAttribute('y', ly + 4);
            text.textContent = item.label;
            group.appendChild(text);

            const heart = document.createElementNS(SVG_NS, 'path');
            heart.setAttribute('d', HEART);
            heart.setAttribute('class', `heart sev-${item.sev}`);
            group.appendChild(heart);
            let width = item.label.length * 6;
            try {
                const measured = text.getComputedTextLength();
                if (measured > 0) width = measured;
            } catch (_) { /* belum ter-render, pakai perkiraan */ }
            heart.setAttribute('transform', `translate(${LABEL_X + width + 4} ${ly - 4.5}) scale(1.3)`);
        });

        const ul = $('injury-list');
        ul.textContent = '';
        if (list.length === 0) {
            const li = document.createElement('li');
            li.textContent = t('noInjury');
            ul.appendChild(li);
            return;
        }
        list.slice(0, 4).forEach((item) => {
            const li = document.createElement('li');
            li.className = `sev-${item.sev}`;
            li.innerHTML = '<i></i><b></b><span></span>';
            li.querySelector('b').textContent = item.label;
            li.querySelector('span').textContent = sevLabels[item.sev - 1] || '';
            ul.appendChild(li);
        });
    }

    function renderBleed(level) {
        level = Math.max(0, Math.min(4, level | 0));
        const labels = (st.locale && st.locale.bleed) || {};
        $('chip-bleed').textContent = `${t('bleeding')}: ${labels[level] || level}`;
        $('bleed-dot').className = `dot bleed lvl-${level}`;
    }

    function renderEms(count) {
        if (typeof count !== 'number') return;
        $('chip-ems').textContent = `${t('emsOnDuty')}: ${count}`;
        $('ems-dot').classList.toggle('on', count > 0);
    }

    // ------------------------------------------------------------------ info

    function renderInfo(info) {
        info = info || {};
        const none = t('none');

        $('location').textContent = info.location || none;
        $('cause').textContent = info.causeLabel || t('unknown');
        $('cause-icon').innerHTML = `<svg viewBox="0 0 24 24"><path fill="currentColor" d="${ICONS[info.cause] || ICONS.unknown}"/></svg>`;

        const img = $('weapon-img');
        img.classList.remove('ok');
        img.removeAttribute('src');
        if (info.image) {
            img.onload = () => img.classList.add('ok');
            img.onerror = () => img.classList.remove('ok');
            img.src = info.image;
        }
        $('weapon').textContent = info.weapon || none;

        $('distance').textContent = info.distance || none;
        $('tod').textContent = info.time || none;
    }

    function setPhase(phase) {
        const dead = phase === 'dead';
        root.classList.toggle('dead', dead);
        $('title').textContent = t(dead ? 'deadTitle' : 'downTitle');
    }

    // ------------------------------------------------------------------ buttons

    function toast(msg, isError) {
        const el = $('toast');
        el.textContent = msg;
        el.classList.toggle('error', !!isError);
        el.classList.add('show');
        clearTimeout(st.toastTimer);
        st.toastTimer = setTimeout(() => el.classList.remove('show'), 3500);
    }

    function press(which) {
        const btn = $(`btn-${which}`);
        btn.classList.remove('pressed');
        void btn.offsetWidth;
        btn.classList.add('pressed');
    }

    function cooldown(which, seconds) {
        const btn = $(`btn-${which}`);
        const bar = btn.querySelector('.cd');
        const key = $(`key-${which}`);
        const label = key.dataset.key || key.textContent;
        key.dataset.key = label;

        if (st.cool[which]) clearInterval(st.cool[which]);
        if (!seconds || seconds <= 0) {
            btn.classList.remove('cooling');
            bar.style.width = '0';
            key.textContent = label;
            return;
        }

        const end = Date.now() + seconds * 1000;
        btn.classList.add('cooling');
        const step = () => {
            const left = Math.max(0, end - Date.now());
            bar.style.width = `${(left / (seconds * 1000)) * 100}%`;
            key.textContent = `${Math.ceil(left / 1000)}s`;
            if (left <= 0) {
                clearInterval(st.cool[which]);
                st.cool[which] = null;
                btn.classList.remove('cooling');
                key.textContent = label;
            }
        };
        step();
        st.cool[which] = setInterval(step, 200);
    }

    function setKeys(keys) {
        keys = keys || {};
        ['dispatch', 'sync'].forEach((k) => {
            const el = $(`key-${k}`);
            el.dataset.key = keys[k] || el.dataset.key || el.textContent;
            if (!st.cool[k]) el.textContent = el.dataset.key;
        });
    }

    // ------------------------------------------------------------------ handlers

    const handlers = {
        open(d) {
            st.locale = d.locale || st.locale;
            st.total = d.total || Math.max(d.remaining || 0, 1);

            $('lbl-dispatch').textContent = t('dispatch');
            $('lbl-sync').textContent = t('sync');
            $('lbl-cause').textContent = t('causeOfDeath');
            $('lbl-weapon').textContent = t('murderWeapon');
            $('lbl-distance').textContent = t('distance');
            $('lbl-time').textContent = t('timeOfDeath');
            st.ai = !!d.ai;
            st.emsPaused = d.emsTreating ? (d.remaining || 0) : null;
            $('subtitle').textContent = t(st.ai ? 'aiComingSub' : st.emsPaused !== null ? 'emsTreating' : 'subtitle');

            setPhase(d.phase);
            setKeys(d.keys);
            renderInfo(d.info);
            renderInjuries(d.injuries);
            renderBleed(d.bleed);
            renderEms(d.ems);
            cooldown('dispatch', 0);
            cooldown('sync', 0);
            $('toast').classList.remove('show');

            setRemaining(d.remaining || 0);
            startTick();

            root.classList.remove('transporting', 'show');
            void root.offsetWidth; // restart animasi masuk
            root.classList.add('show');
        },

        close() {
            stopTick();
            root.classList.remove('show', 'transporting');
        },

        phase(p) { setPhase(p); },
        injuries(inj) { renderInjuries(inj); },
        bleed(level) { renderBleed(level); },
        press(which) { press(which); },

        dispatch(res) {
            if (!res) return;
            if (res.ok && res.ai) {
                renderEms(res.ems);
                st.ai = true;
                renderTimer();
                $('subtitle').textContent = t('aiComingSub');
                toast(t('aiComing', res.price));
                cooldown('dispatch', res.cooldown);
            } else if (res.ok) {
                renderEms(res.ems);
                toast(res.sent > 0 ? t('dispatchSent', res.sent) : t('dispatchNoEms'), res.sent === 0);
                cooldown('dispatch', res.cooldown);
            } else if (res.reason === 'cooldown') {
                toast(t('cooldown', res.wait), true);
                cooldown('dispatch', res.wait);
            } else if (res.reason === 'nomoney') {
                toast(t('aiNoMoney', res.price), true);
            } else if (res.reason === 'aibusy') {
                toast(t('aiBusy'), true);
            }
        },

        // EMS menangani lewat panel Cek Pasien: countdown dijeda / lanjut
        ems(d) {
            if (!d) return;
            if (d.active) {
                st.emsPaused = d.remaining || 0;
                $('subtitle').textContent = t('emsTreating');
            } else {
                st.emsPaused = null;
                setRemaining(d.remaining || 0);
                $('subtitle').textContent = t(st.ai ? 'aiComingSub' : 'subtitle');
            }
            renderTimer();
        },

        // status dokter AI dari client Lua ('aiComingSub' / 'aiTreating')
        status(key) {
            st.ai = true;
            renderTimer();
            $('subtitle').textContent = t(key);
        },

        sync(res) {
            if (!res) return;
            if (res.ok) {
                if (typeof res.remaining === 'number') {
                    if (st.emsPaused !== null) st.emsPaused = res.remaining;
                    else setRemaining(res.remaining);
                }
                if (res.injuries) renderInjuries(res.injuries);
                if (typeof res.bleed === 'number') renderBleed(res.bleed);
                renderEms(res.ems);
                toast(t('syncDone'));
                cooldown('sync', res.cooldown);
            } else if (res.reason === 'cooldown') {
                toast(t('cooldown', res.wait), true);
                cooldown('sync', res.wait);
            }
        },

        transport(label) {
            $('transport-text').textContent = t('transport', label || '');
            root.classList.add('transporting');
        },
    };

    window.addEventListener('message', (e) => {
        const msg = e.data;
        if (!msg || typeof msg.action !== 'string') return;
        const fn = handlers[msg.action];
        if (fn) fn(msg.data);
    });
})();
