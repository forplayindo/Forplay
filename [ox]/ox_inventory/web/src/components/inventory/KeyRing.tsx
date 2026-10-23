import React, { useRef } from 'react';
import { useDrag, useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { getKeyItems, keyItem, keySlots } from '../../store/hotbar';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { openContextMenu } from '../../store/contextMenu';
import { getItemUrl, isSlotWithItem } from '../../helpers';
import { onDrop } from '../../dnd/onDrop';
import { onUse } from '../../dnd/onUse';
import { Locale } from '../../store/locale';
import { DragSource, InventoryType, Slot, SlotWithItem } from '../../typings';

/** Only keys from the player's own inventory or an opened inventory (trunk, stash, drop...) may be dropped here. */
const acceptsSource = (source: DragSource) =>
  source.item.name === keyItem && source.inventory !== InventoryType.SHOP && source.inventory !== InventoryType.CRAFTING;

const KeyIcon: React.FC = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="M7 14a3 3 0 1 1 0-6 3 3 0 0 1 0 6zm5.65-4A6 6 0 1 0 12.65 14H17v3h3v-3h2v-4z" />
  </svg>
);

/** One stored key: drag it out like any slot, drop another key on it to swap. */
const KeyRow: React.FC<{ item: SlotWithItem }> = ({ item }) => {
  const dispatch = useAppDispatch();
  const timerRef = useRef<number | null>(null);

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({ isDragging: monitor.isDragging() }),
      item: () => ({
        inventory: InventoryType.PLAYER,
        item: { name: item.name, slot: item.slot },
        image: `url(${getItemUrl(item) || 'none'}`,
      }),
    }),
    [item]
  );

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({ isOver: monitor.isOver() && monitor.canDrop() }),
      drop: (source) => {
        dispatch(closeTooltip());
        onDrop(source, { inventory: InventoryType.PLAYER, item: { slot: item.slot } });
      },
      canDrop: (source) =>
        acceptsSource(source) && (source.item.slot !== item.slot || source.inventory !== InventoryType.PLAYER),
    }),
    [item]
  );

  const clearTimer = () => {
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = null;
  };

  return (
    <div
      ref={(element) => {
        if (element) drag(drop(element));
      }}
      className={`keyring-item${isOver ? ' is-over' : ''}`}
      style={{ opacity: isDragging ? 0.4 : 1 }}
      onMouseEnter={() => {
        timerRef.current = window.setTimeout(
          () => dispatch(openTooltip({ item, inventoryType: InventoryType.PLAYER })),
          500
        ) as unknown as number;
      }}
      onMouseLeave={() => {
        dispatch(closeTooltip());
        clearTimer();
      }}
      onContextMenu={(event) => {
        event.preventDefault();
        dispatch(openContextMenu({ item, coords: { x: event.clientX, y: event.clientY } }));
      }}
      onClick={(event) => {
        dispatch(closeTooltip());
        clearTimer();
        if (event.ctrlKey) onDrop({ item, inventory: InventoryType.PLAYER });
        else if (event.altKey) onUse(item);
      }}
    >
      <img className="keyring-item-image" src={getItemUrl(item)} alt="" draggable={false} />
      <div className="keyring-item-text">
        {item.metadata?.plate && <span className="keyring-item-plate">{item.metadata.plate}</span>}
        <span className="keyring-item-name">{item.metadata?.vehicle || item.metadata?.label || item.name}</span>
      </div>
    </div>
  );
};

/** Drop target shown while the ring still has room: a key dropped here goes to the first free key slot. */
const KeyDropZone: React.FC<{ slot: Slot }> = ({ slot }) => {
  const dispatch = useAppDispatch();

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({ isOver: monitor.isOver() && monitor.canDrop() }),
      drop: (source) => {
        dispatch(closeTooltip());
        onDrop(source, { inventory: InventoryType.PLAYER, item: { slot: slot.slot } });
      },
      canDrop: acceptsSource,
    }),
    [slot]
  );

  return (
    <div
      ref={(element) => {
        if (element) drop(element);
      }}
      className={`keyring-empty${isOver ? ' is-over' : ''}`}
    >
      {Locale.ui_keyring_empty || 'Drag keys here'}
    </div>
  );
};

const KeyRing: React.FC = () => {
  const items = getKeyItems(useAppSelector(selectLeftInventory).items);

  if (keySlots <= 0) return null;

  const keys = items.filter((slot): slot is SlotWithItem => isSlotWithItem(slot));
  const freeSlot = items.find((slot) => !slot.name);

  return (
    <div className="keyring">
      <div className="keyring-header">
        <KeyIcon />
        <p className="keyring-title">{Locale.ui_keyring || 'Key Ring'}</p>
        <p className="keyring-count">
          {keys.length}/{keySlots}
        </p>
      </div>
      <div className="keyring-list">
        {keys.map((item) => (
          <KeyRow key={`key-${item.slot}`} item={item} />
        ))}
        {freeSlot && <KeyDropZone slot={freeSlot} />}
      </div>
    </div>
  );
};

export default KeyRing;
