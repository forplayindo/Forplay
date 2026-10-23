import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Inventory } from '../../typings';
import WeightBar from '../utils/WeightBar';
import InventorySlot from './InventorySlot';
import { getTotalWeight } from '../../helpers';
import { useAppSelector } from '../../store';
import { useIntersection } from '../../hooks/useIntersection';
import { Locale } from '../../store/locale';
import { PlayerPanelIcon, StoragePanelIcon } from '../utils/icons/InventoryIcons';
import CloseButton from './CloseButton';
import { getGridItems } from '../../store/hotbar';

const PAGE_SIZE = 30;

/** Title + subtitle shown in the panel header. */
const getPanelHeading = (inventory: Inventory, side: 'left' | 'right') => {
  if (side === 'left')
    return {
      title: inventory.label || Locale.ui_player_inventory || 'Inventory',
      subtitle: Locale.ui_player_description || 'Items on your character.',
    };

  switch (inventory.type) {
    case 'newdrop':
    case 'drop':
      return {
        title: Locale.ui_ground || 'Ground',
        // a drop is identified by its inventory id, e.g. drop-482913
        subtitle: inventory.id || Locale.ui_ground_description || 'Drop or pick up items here.',
      };
    case 'shop':
      return {
        title: inventory.label || Locale.ui_shop || 'Shop',
        subtitle: Locale.ui_shop_description || 'Drag an item over to buy.',
      };
    case 'crafting':
      return {
        title: inventory.label || Locale.ui_crafting || 'Crafting',
        subtitle: Locale.ui_crafting_description || 'Drag a recipe over to craft.',
      };
    case 'otherplayer':
      return {
        title: inventory.label || Locale.ui_player || 'Player',
        subtitle: Locale.ui_otherplayer_description || 'Items this person carries.',
      };
    default:
      return {
        title: inventory.label || Locale.ui_storage || 'Storage',
        // stashes, trunks and gloveboxes are easier to tell apart by their id
        subtitle: inventory.id || Locale.ui_storage_description || 'Items stored here.',
      };
  }
};

const InventoryGrid: React.FC<{ inventory: Inventory; side: 'left' | 'right' }> = ({ inventory, side }) => {
  const weight = useMemo(
    () => (inventory.maxWeight !== undefined ? Math.floor(getTotalWeight(inventory.items) * 1000) / 1000 : 0),
    [inventory.maxWeight, inventory.items]
  );
  const [page, setPage] = useState(0);
  const containerRef = useRef(null);
  const { ref, entry } = useIntersection({ threshold: 0.5 });
  const isBusy = useAppSelector((state) => state.inventory.isBusy);
  const heading = useMemo(() => getPanelHeading(inventory, side), [inventory.id, inventory.label, inventory.type, side]);
  // The last slots of the player's inventory belong to the quick action bar and the key ring.
  const gridItems = useMemo(
    () => (side === 'left' ? getGridItems(inventory.items) : inventory.items),
    [inventory.items, side]
  );
  const percent = inventory.maxWeight ? (weight / inventory.maxWeight) * 100 : 0;

  useEffect(() => {
    if (entry && entry.isIntersecting) {
      setPage((prev) => ++prev);
    }
  }, [entry]);

  return (
    <div className="inventory-panel" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      {/* Keeps both panels aligned; the close button only sits above the right one. */}
      <div className="inventory-panel-topbar">{side === 'right' && <CloseButton />}</div>

      <div className="inventory-panel-header">
        <div className="inventory-panel-icon">{side === 'left' ? <PlayerPanelIcon /> : <StoragePanelIcon />}</div>
        <div className="inventory-panel-heading">
          <p className="inventory-panel-title">{heading.title}</p>
          <p className="inventory-panel-subtitle">{heading.subtitle}</p>
        </div>
        {inventory.maxWeight !== undefined && (
          <div className="inventory-panel-weight">
            <p className="inventory-panel-weight-value">
              {weight / 1000}/{inventory.maxWeight / 1000}kg
            </p>
            <WeightBar percent={percent} segmented />
          </div>
        )}
      </div>

      <div className="inventory-grid-container" ref={containerRef}>
        {gridItems.slice(0, (page + 1) * PAGE_SIZE).map((item, index) => (
          <InventorySlot
            key={`${inventory.type}-${inventory.id}-${item.slot}`}
            item={item}
            ref={index === (page + 1) * PAGE_SIZE - 1 ? ref : null}
            inventoryType={inventory.type}
            inventoryGroups={inventory.groups}
            inventoryId={inventory.id}
          />
        ))}
      </div>

    </div>
  );
};

export default InventoryGrid;
