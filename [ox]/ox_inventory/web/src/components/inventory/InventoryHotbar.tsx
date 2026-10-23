import React, { useState } from 'react';
import { useDrag, useDrop } from 'react-dnd';
import { getItemUrl, isSlotWithItem } from '../../helpers';
import useNuiEvent from '../../hooks/useNuiEvent';
import WeightBar from '../utils/WeightBar';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { DragSource, Slot, SlotWithItem } from '../../typings';
import SlideUp from '../utils/transitions/SlideUp';
import { onDrop } from '../../dnd/onDrop';
import { onUse } from '../../dnd/onUse';
import { closeTooltip } from '../../store/tooltip';
import { getHotbarItems } from '../../store/hotbar';

const formatWeight = (weight: number) => {
  if (!weight || weight <= 0) return '';

  return weight >= 1000
    ? `${(weight / 1000).toLocaleString('en-us', { minimumFractionDigits: 2 })}kg`
    : `${weight.toLocaleString('en-us', { minimumFractionDigits: 0 })}g`;
};

/** A single quick-action slot: accepts items dragged from the inventory and can be dragged out. */
const HotbarSlot: React.FC<{ item: Slot; hotkey: number }> = ({ item, hotkey }) => {
  const dispatch = useAppDispatch();

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({ isDragging: monitor.isDragging() }),
      item: () =>
        isSlotWithItem(item)
          ? {
              inventory: 'player',
              item: { name: item.name, slot: item.slot },
              image: item?.name && `url(${getItemUrl(item as SlotWithItem) || 'none'}`,
            }
          : null,
    }),
    [item]
  );

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({ isOver: monitor.isOver() }),
      drop: (source) => {
        dispatch(closeTooltip());
        onDrop(source, { inventory: 'player', item: { slot: item.slot } });
      },
      canDrop: (source) =>
        source.inventory !== 'shop' &&
        source.inventory !== 'crafting' &&
        (source.item.slot !== item.slot || source.inventory !== 'player'),
    }),
    [item]
  );

  return (
    <div
      ref={(element) => {
        if (element) drag(drop(element));
      }}
      className="hotbar-item-slot"
      onClick={(event) => {
        if (event.altKey && isSlotWithItem(item)) onUse(item);
      }}
      style={{
        backgroundImage: `url(${item?.name ? getItemUrl(item as SlotWithItem) : 'none'}`,
        opacity: isDragging ? 0.4 : 1,
        borderColor: isOver ? 'rgba(243, 179, 84, 0.85)' : undefined,
      }}
    >
      <div className="hotbar-slot-key">{hotkey}</div>
      {isSlotWithItem(item) && (
        <div className="item-slot-wrapper">
          <div className="hotbar-slot-header-wrapper">
            <p className="hotbar-slot-count">{item.count > 1 ? `${item.count.toLocaleString('en-us')}x` : ''}</p>
          </div>
          <div className="hotbar-slot-bottom">
            <p className="hotbar-slot-weight">{formatWeight(item.weight)}</p>
            {item?.durability !== undefined && <WeightBar percent={item.durability} durability />}
          </div>
        </div>
      )}
    </div>
  );
};

/**
 * `docked`: static row under the inventory panels (inventory open).
 * Otherwise the quick-view toggled by the hotbar key; `suppressed` hides it while the inventory is open.
 */
const InventoryHotbar: React.FC<{ docked?: boolean; suppressed?: boolean }> = ({ docked, suppressed }) => {
  const [hotbarVisible, setHotbarVisible] = useState(false);
  const items = getHotbarItems(useAppSelector(selectLeftInventory).items);

  //stupid fix for timeout
  const [handle, setHandle] = useState<ReturnType<typeof setTimeout>>();
  useNuiEvent('toggleHotbar', () => {
    if (docked) return;
    if (hotbarVisible) {
      setHotbarVisible(false);
    } else {
      if (handle) clearTimeout(handle);
      setHotbarVisible(true);
      setHandle(setTimeout(() => setHotbarVisible(false), 3000));
    }
  });

  const slots = (
    <div className="hotbar-container">
      {items.map((item, index) => (
        <HotbarSlot key={`hotbar-${item.slot}`} item={item} hotkey={index + 1} />
      ))}
    </div>
  );

  if (docked) return <div className="hotbar-wrapper is-docked">{slots}</div>;

  return (
    <SlideUp in={!suppressed && hotbarVisible}>
      <div className="hotbar-wrapper">{slots}</div>
    </SlideUp>
  );
};

export default InventoryHotbar;
