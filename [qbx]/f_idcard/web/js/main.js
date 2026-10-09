import { fetchNui } from './fetchNui.js';
import { Global } from '../../lang/global.js';
import config from './config.js';

/**
 * Get element by id
 * @param id {string}
 **/
const getElementById = (id) => document.getElementById(id);

/**
 * Set visibility
 * @param visibility {string}
 **/
const setVisibility = (visibility) => getElementById('um-idcard').style.visibility = visibility;

/**
 * Set visibility of badge
 * @param badge {string|Object|null}
 **/
const setBadgeVisibility = (badge) => {
  const badgeElement = getElementById('badge');
  if (!badge || badge === 'none') {
    badgeElement.style.display = 'none';
    return;
  }
  getElementById('badgeimg').src = `badges/${badge.img}.png`;
  getElementById('badgegrade').textContent = badge.grade;
  badgeElement.style.display = 'flex';
};

/**
 * Show/hide the "Expired" stamp and highlight the expired date field
 * @param isExpired {boolean}
 **/
const setExpiredState = (isExpired) => {
  getElementById('expired-stamp').style.display = isExpired ? 'block' : 'none';
  getElementById('expired').classList.toggle('is-expired', !!isExpired);
};

/**
 * Judul, subjudul, label pojok & tema warna per jenis kartu (config/shared.lua).
 * Judul panjang diperkecil supaya tidak menumpuk.
 * @param license {Object}
 **/
const applyLicense = (license) => {
  const card = getElementById('um-idcard');
  const title = getElementById('cardtype');
  title.textContent = license.header;
  title.classList.toggle('is-long', license.header.length > 22 && license.header.length <= 30);
  title.classList.toggle('is-xlong', license.header.length > 30);
  getElementById('subtitle').textContent = license.subtitle || '';
  getElementById('tier').textContent = license.tier || 'Dokumen Resmi';
  card.classList.toggle('theme-temp', license.theme === 'temp');
  card.style.backgroundImage = `url(${license.backgroundImage})`;
  card.style.backgroundColor = license.background;
};

const closeFunction = () => {
  getElementById('um-idcard').classList.remove('animate__animated', 'animate__fadeInLeft', 'animate__faster');
  setVisibility('hidden');
  setBadgeVisibility('none');
  fetchNui('closeIdCard');
};

const STNK_LABELS = {
  lang_firstname: 'Kendaraan',
  lang_lastname: 'Plat Nomor',
  lang_dob: 'Pemilik',
  lang_sex: 'Diterbitkan',
  lang_job: 'Berlaku Plat',
  lang_expired: 'Pajak',
};

const CAR_SILHOUETTE = 'data:image/svg+xml;utf8,' + encodeURIComponent(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 40"><rect width="64" height="40" fill="#d9cdb2"/>' +
  '<path fill="#8d7c62" d="M10 26l4-8c1-2 3-3 5-3h20c2 0 4 1 5 2l6 6 5 1c1 0 2 1 2 2v4h-4a5 5 0 0 0-10 0H21a5 5 0 0 0-10 0H8v-3c0-1 1-1 2-1z"/>' +
  '<circle cx="16" cy="30" r="3.5" fill="#6b5c46"/><circle cx="48" cy="30" r="3.5" fill="#6b5c46"/></svg>'
);

const setLabels = (labels) => {
  Object.entries(labels).forEach(([key, value]) => {
    getElementById(key).textContent = value;
  });
};

/**
 * Vehicle photo: local addon photo -> official FiveM image -> silhouette
 * @param model {string}
 **/
const setVehiclePhoto = (model) => {
  const img = getElementById('mugshot');
  const safe = String(model || '').replace(/[^a-z0-9_]/gi, '');
  const sources = [`nui://f_vehimages/images/${safe}.webp`, `https://docs.fivem.net/vehicles/${safe}.webp`, CAR_SILHOUETTE];
  let index = 0;
  img.onerror = () => {
    index += 1;
    if (index < sources.length) img.src = sources[index];
    else img.onerror = null;
  };
  img.src = safe ? sources[0] : CAR_SILHOUETTE;
};

/**
 * Open STNK (vehicle registration)
 * @param data {Object}
 **/
const openStnk = (data) => {
  const license = config.licenses.stnk;
  setLabels(STNK_LABELS);

  const values = {
    name: data.vehicle || '-',
    lastname: data.plate || '-',
    dob: data.owner || '-',
    sex: data.issued || '-',
    job: data.plateExpire || '-',
    expired: data.taxExpire || 'Belum bayar',
    sign: data.owner || '',
  };
  Object.entries(values).forEach(([key, value]) => {
    getElementById(key).textContent = value;
  });

  getElementById('job').classList.toggle('is-expired', !!data.plateExpired);
  getElementById('expired').classList.toggle('is-expired', !!data.taxExpired || !data.taxExpire);

  const stamp = getElementById('expired-stamp');
  stamp.textContent = data.invalid ? 'Tidak Berlaku' : 'Kedaluwarsa';
  stamp.style.display = data.invalid || data.plateExpired || data.taxExpired ? 'block' : 'none';

  const card = getElementById('um-idcard');
  card.classList.add('is-vehicle');
  setVehiclePhoto(data.model);
  applyLicense(license);
  card.classList.add('animate__animated', 'animate__fadeInLeft', 'animate__faster');
  setBadgeVisibility('none');
  setVisibility('visible');
  autoClose();
};

/**
 * Open id card
 * @param playerData {Object}
 **/
const openIdCard = (playerData) => {
  if (playerData.cardtype === 'stnk') return openStnk(playerData);

  setLabels(Global);
  getElementById('um-idcard').classList.remove('is-vehicle');
  getElementById('job').classList.remove('is-expired');
  getElementById('expired-stamp').textContent = 'Kedaluwarsa';
  getElementById('mugshot').onerror = null;

  const license = config.licenses[playerData.cardtype];
  const elements = {
    lastname: playerData.lastname,
    name: playerData.firstname,
    sign: `${playerData.firstname} ${playerData.lastname}`,
    dob: playerData.birthdate,
    sex: playerData.sex,
    job: playerData.job,
    expired: playerData.expired,
  };

  Object.entries(elements).forEach(([key, value]) => {
    getElementById(key).textContent = value;
  });

  getElementById('mugshot').src = playerData.mugShot;
  applyLicense(license);
  getElementById('um-idcard').classList.add('animate__animated', 'animate__fadeInLeft', 'animate__faster');
  setBadgeVisibility(playerData.badge);
  setExpiredState(playerData.isExpired);
  if (playerData.isRevoked) {
    getElementById('expired-stamp').textContent = 'Dicabut';
    getElementById('expired-stamp').style.display = 'block';
  }
  setVisibility('visible');
  autoClose();
};

const autoClose = () => {
  if (!config.idCardSettings.autoClose.status) return;
  setTimeout(closeFunction, config.idCardSettings.autoClose.time);
};

window.addEventListener('message', (event) => {
  const { type, playerData, configData } = event.data;
  if (type === 'playerData') {
    openIdCard(playerData);
  } else if (type === 'configData') {
    Object.assign(config, configData);
  }
});

window.addEventListener('load', () => setLabels(Global));

document.addEventListener('keydown', (e) => {
  if (e.key !== config.idCardSettings.closeKey) return;
  closeFunction();
});
