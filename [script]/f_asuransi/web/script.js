/* Asuransi Keliling — Liquid Glass HUD
   Event NUI (dari client.lua): openui, updateTimer, closeui. Tanpa jQuery. */
(function () {
    'use strict';

    var app = document.getElementById('app');

    var ICONS = {
        car: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 16V11.5L7 6.5C7.3 5.8 7.9 5.4 8.7 5.4H15.3C16.1 5.4 16.7 5.8 17 6.5L19 11.5V16"/><path d="M3.5 11.5H20.5"/><rect x="4" y="11.5" width="16" height="5" rx="1.5"/><path d="M6.5 16.5V18.5"/><path d="M17.5 16.5V18.5"/></svg>',
        warning: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4L21 19.5H3L12 4Z"/><path d="M12 10V14"/><path d="M12 16.8h.01"/></svg>',
        clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="13" r="7.5"/><path d="M12 9V13L14.5 14.5"/><path d="M9.5 3H14.5"/></svg>',
        check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5.5 12.5L10 17L18.5 7.5"/></svg>'
    };

    var POSITIONS = ['topLeft', 'topCenter', 'topRight', 'middleLeft', 'center', 'middleRight', 'bottomLeft', 'bottomCenter', 'bottomRight'];
    var THEMES = ['dark', 'white', 'blue', 'red', 'green', 'pink'];

    var WARNING_AT = 15; // detik
    var FINAL_AT = 5;    // detik

    var ui = null;       // elemen yang sedang tampil
    var hideTimeout = null;
    var removeTimeout = null;

    /* ---------- util ---------- */
    function clamp(n, min, max) { return Math.min(max, Math.max(min, n)); }

    function pad(n) { return (n < 10 ? '0' : '') + n; }

    function fmt(sec) { return pad(Math.floor(sec / 60)) + ':' + pad(sec % 60); }

    function toSeconds(str) {
        var parts = String(str).split(':').map(Number);
        for (var i = 0; i < parts.length; i++) if (isNaN(parts[i])) return null;
        if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
        if (parts.length === 2) return parts[0] * 60 + parts[1];
        return parts[0];
    }

    function playSound(file, volume) {
        if (!file || file === 'none') return;
        try {
            var audio = new Audio('music/' + file);
            audio.volume = clamp(Number(volume) || 0.2, 0, 1);
            var p = audio.play();
            if (p && p.catch) p.catch(function () {});
        } catch (e) { /* abaikan */ }
    }

    // null = pakai ikon bawaan (SVG). Selain itu: URL atau file di web/assets/
    function resolveLogo(logo) {
        if (!logo) return null;
        logo = String(logo);
        if (logo === 'none' || logo === 'default' || logo === 'assets/default' || logo === 'assets/none') return null;
        if (/^(https?:|nui:|assets\/)/.test(logo)) return logo;
        return 'assets/' + logo;
    }

    function el(tag, cls) {
        var node = document.createElement(tag);
        if (cls) node.className = cls;
        return node;
    }

    function setIcon(name) {
        if (!ui) return;
        if (ui.customLogo) return; // logo kustom tetap dipakai di semua fase
        ui.icon.innerHTML = ICONS[name] || ICONS.car;
    }

    function setLogo(src, fallbackIcon) {
        ui.customLogo = !!src;
        ui.icon.textContent = '';
        if (src) {
            var img = el('img');
            img.alt = '';
            img.src = src;
            img.onerror = function () { ui && (ui.customLogo = false); setIcon(fallbackIcon); };
            ui.icon.appendChild(img);
        } else {
            ui.icon.innerHTML = ICONS[fallbackIcon];
        }
    }

    function bump(node) {
        node.classList.remove('ak-bump');
        void node.offsetWidth; // restart animasi
        node.classList.add('ak-bump');
    }

    function clearTimers() {
        clearTimeout(hideTimeout);
        clearTimeout(removeTimeout);
        hideTimeout = removeTimeout = null;
    }

    /* ---------- render ---------- */
    function build(data) {
        clearTimers();
        app.textContent = '';

        var position = POSITIONS.indexOf(data.position) >= 0 ? data.position : 'topCenter';
        var theme = THEMES.indexOf(data.color) >= 0 ? data.color : 'dark';

        var wrap = el('div', 'ak-wrap pos-' + position);
        var box = el('div', 'ak theme-' + theme);
        var icon = el('div', 'ak-icon');
        var text = el('div', 'ak-text');
        var title = el('div', 'ak-title');
        var desc = el('div', 'ak-desc');
        var timer = el('div', 'ak-timer');
        var progress = el('div', 'ak-progress');
        var fill = el('div', 'ak-progress-fill');

        text.appendChild(title);
        text.appendChild(desc);
        progress.appendChild(fill);
        box.appendChild(icon);
        box.appendChild(text);
        box.appendChild(timer);
        box.appendChild(progress);
        wrap.appendChild(box);
        app.appendChild(wrap);

        ui = {
            wrap: wrap, box: box, icon: icon, title: title, desc: desc,
            timer: timer, fill: fill,
            total: 60, phase: 'normal', customLogo: false,
            texts: {}, endSound: null, endVolume: 0.2, endPlayed: false
        };

        // masuk: 2 frame agar transisi jalan
        requestAnimationFrame(function () {
            requestAnimationFrame(function () { box.classList.add('is-in'); });
        });

        return ui;
    }

    function setPhase(phase) {
        if (!ui || ui.phase === phase) return;
        ui.phase = phase;
        ui.box.classList.remove('is-warning', 'is-final');

        if (phase === 'warning') {
            ui.box.classList.add('is-warning');
            setIcon('warning');
            if (ui.texts.warning) ui.desc.textContent = ui.texts.warning;
            bump(ui.timer);
        } else if (phase === 'final') {
            ui.box.classList.add('is-final');
            setIcon('clock');
            if (ui.texts.final) ui.desc.textContent = ui.texts.final;
            bump(ui.timer);
        }
    }

    /* ---------- handler ---------- */
    function onOpen(data) {
        data = data || {};
        build(data);

        var minutes = Math.max(Number(data.time_nui) || 1, 0.1);
        ui.total = Math.round(minutes * 60);
        ui.texts = {
            normal: data.description || '',
            warning: data.warning_text || '',
            final: data.final_text || ''
        };

        ui.title.textContent = data.tittle || 'Asuransi Keliling';
        ui.desc.textContent = ui.texts.normal;
        ui.timer.textContent = fmt(ui.total);
        setLogo(resolveLogo(data.logo), 'car');

        playSound(data.start_sound, data.start_volume);
    }

    function onUpdate(data) {
        if (!ui || ui.phase === 'done' || !data) return;

        var sec = toSeconds(data.timer);
        if (sec === null) return;

        ui.timer.textContent = data.timer;
        ui.fill.style.transform = 'scaleX(' + clamp(sec / ui.total, 0, 1) + ')';

        if (sec <= FINAL_AT) {
            setPhase('final');
            if (!ui.endPlayed) {
                ui.endPlayed = true;
                playSound(data.end_sound, data.end_volume);
            }
        } else if (sec <= WARNING_AT) {
            setPhase('warning');
        }
    }

    function onClose(data) {
        data = data || {};
        if (!ui) build(data); // pemain yang baru masuk di tengah hitungan

        clearTimers();
        ui.phase = 'done';
        ui.box.classList.remove('is-warning', 'is-final');
        ui.box.classList.add('is-done');

        setLogo(resolveLogo(data.logo), 'check');
        ui.title.textContent = data.tittle || 'Kendaraan sudah dibersihkan';
        ui.desc.textContent = data.description || '';

        playSound(data.clear_sound, data.clear_volume);

        var box = ui.box;
        hideTimeout = setTimeout(function () {
            box.classList.remove('is-in');
            box.classList.add('is-out');
            removeTimeout = setTimeout(function () {
                app.textContent = '';
                ui = null;
            }, 350);
        }, 5000);
    }

    window.addEventListener('message', function (event) {
        var msg = event.data;
        if (!msg || !msg.type) return;
        if (msg.type === 'openui') onOpen(msg.data);
        else if (msg.type === 'updateTimer') onUpdate(msg.data);
        else if (msg.type === 'closeui') onClose(msg.data);
    });
})();
