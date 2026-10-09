import React from 'react';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';
import { CloseIcon } from '../utils/icons/InventoryIcons';

const CloseButton: React.FC = () => (
  <div className="inventory-close">
    <div className="inventory-close-label">
      <span className="inventory-close-action">{Locale.ui_close || 'Close'}</span>
      <span className="inventory-close-target">{Locale.ui_inventory || 'Inventory'}</span>
    </div>
    <button className="inventory-close-button" onClick={() => fetchNui('exit')} aria-label={Locale.ui_close || 'Close'}>
      <CloseIcon />
    </button>
  </div>
);

export default CloseButton;
