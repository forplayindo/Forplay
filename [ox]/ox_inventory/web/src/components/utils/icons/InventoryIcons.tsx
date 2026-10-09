import React from 'react';

/**
 * Icon shown on the player (left) panel header.
 */
export const PlayerPanelIcon: React.FC = () => (
  <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    {[6, 12, 18].map((y) => [6, 12, 18].map((x) => <circle key={`${x}-${y}`} cx={x} cy={y} r="1.6" />))}
  </svg>
);

/**
 * Icon shown on the secondary (right) panel header - ground, stash, shop, etc.
 */
export const StoragePanelIcon: React.FC = () => (
  <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <path d="M12 3a1.4 1.4 0 0 1 1.4 1.4v7.3l2.5-2.5a1.4 1.4 0 1 1 2 2l-4.9 4.9a1.4 1.4 0 0 1-2 0L6.1 11.2a1.4 1.4 0 1 1 2-2l2.5 2.5V4.4A1.4 1.4 0 0 1 12 3Z" />
    <path d="M4.9 16.4a1.4 1.4 0 0 1 1.4 1.4v.8h11.4v-.8a1.4 1.4 0 1 1 2.8 0v1.4A2.2 2.2 0 0 1 18.3 21H5.7a2.2 2.2 0 0 1-2.2-2.2v-1.4a1.4 1.4 0 0 1 1.4-1.4Z" />
  </svg>
);

/**
 * Icon shown on the hotbar header.
 */
export const HotbarIcon: React.FC = () => (
  <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <path d="M13.6 2.2a1 1 0 0 1 .6 1.1L13.1 9.4h5a1.2 1.2 0 0 1 .95 1.93l-8.2 10.6a1 1 0 0 1-1.77-.8l1.1-6.13H5.9a1.2 1.2 0 0 1-.95-1.93l8.2-10.6a1 1 0 0 1 .45-.27Z" />
  </svg>
);

export const CloseIcon: React.FC = () => (
  <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <path d="M6.4 5a1.4 1.4 0 0 0-1 2.4l4.6 4.6-4.6 4.6a1.4 1.4 0 0 0 2 2l4.6-4.6 4.6 4.6a1.4 1.4 0 0 0 2-2L14 12l4.6-4.6a1.4 1.4 0 0 0-2-2L12 10 7.4 5.4A1.4 1.4 0 0 0 6.4 5Z" />
  </svg>
);

/**
 * PLACEHOLDER LOGO
 * ----------------
 * Swap this out for your own server logo by setting LOGO_URL below, for example:
 *   const LOGO_URL = 'https://your-cdn.com/logo.png';
 * or, if you copy an image into `web/images/`:
 *   const LOGO_URL = 'images/logo.png';
 * Leave it empty to keep the placeholder mark.
 */
const LOGO_URL = '';

export const BrandLogo: React.FC = () => {
  if (LOGO_URL) return <img className="inventory-brand-image" src={LOGO_URL} alt="" draggable={false} />;

  return (
    <svg className="inventory-brand-mark" viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <g fill="none" strokeWidth="2" strokeLinejoin="round">
        <rect x="26" y="26" width="68" height="68" rx="6" transform="rotate(45 60 60)" opacity="0.35" />
        <rect x="38" y="38" width="44" height="44" rx="4" transform="rotate(45 60 60)" opacity="0.6" />
        <rect x="50" y="50" width="20" height="20" rx="2" transform="rotate(45 60 60)" />
      </g>
      <text x="60" y="65" textAnchor="middle" className="inventory-brand-text">
        LOGO
      </text>
    </svg>
  );
};
