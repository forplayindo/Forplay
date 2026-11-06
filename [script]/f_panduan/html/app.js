const $ = (id) => document.getElementById(id);
let D = null;       // { jobs, job, active, step, browse, last }
let job = null;     // kunci job yang sedang ditampilkan

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    }).catch(() => {});
}

const jobOf = (key) => D.jobs.find((j) => j.key === key) || D.jobs[0];

function render() {
    const j = jobOf(job);
    // step 1-based dari Lua, hanya untuk job yang sedang dikerjakan
    const now = j.key === D.active && D.step ? D.step - 1 : -1;
    $('f-icon').setAttribute('href', '#i-' + j.icon);
    $('f-title').textContent = 'Alur Kerja ' + j.name;

    $('f-tabs').classList.toggle('hidden', !D.browse);
    $('f-tabs').innerHTML = D.jobs.map((x) => `<button data-job="${x.key}" class="${x.key === j.key ? 'active' : ''}">${x.name}</button>`).join('');

    $('f-steps').innerHTML = j.steps.map(([title, desc], i) => {
        const cls = now < 0 ? '' : i < now ? 'done' : i === now ? 'now' : '';
        const no = i < now ? '<svg class="ic"><use href="#i-check"/></svg>' : i + 1;
        return `<div class="st ${cls}"><span class="no">${no}</span><div><h3>${title}${i === now ? '<span class="chip-now">Sekarang</span>' : ''}</h3><p>${desc}</p></div></div>`;
    }).join('');

    const rules = j.rules || [];
    $('f-rules').classList.toggle('hidden', rules.length === 0);
    $('f-rules').innerHTML = `<b><svg class="ic"><use href="#i-warn"/></svg>Perhatikan</b><ul>${rules.map((r) => `<li>${r}</li>`).join('')}</ul>`;

    $('f-last').classList.toggle('hidden', !(D.last && j.key === D.job));
    $('f-mute').checked = !!j.muted;
}

$('f-tabs').addEventListener('click', (e) => {
    const b = e.target.closest('[data-job]');
    if (!b) return;
    job = b.dataset.job;
    render();
    $('f-steps').parentElement.scrollTop = 0;
});

$('f-mute').addEventListener('change', () => { jobOf(job).muted = $('f-mute').checked; });

function close() {
    if (!D) return;
    post('close', { job, mute: $('f-mute').checked });
}
$('f-close').addEventListener('click', close);
$('f-ok').addEventListener('click', close);
document.addEventListener('keydown', (e) => {
    if ((e.key === 'Escape' || e.key === 'F7') && !$('flow').classList.contains('hidden')) close();
});

window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') {
        D = data.data;
        job = D.job;
        render();
        $('flow').classList.remove('hidden');
        $('f-steps').parentElement.scrollTop = 0;
    } else if (data.action === 'step') {
        if (!D) return;
        D.step = data.step;
        if (!$('flow').classList.contains('hidden')) render();
    } else if (data.action === 'close') {
        $('flow').classList.add('hidden');
    }
});
