import InventoryComponent from './components/inventory';
import useNuiEvent from './hooks/useNuiEvent';
import { Items } from './store/items';
import { Locale } from './store/locale';
import { setImagePath } from './store/imagepath';
import { setHotbarSlots } from './store/hotbar';
import { setupInventory } from './store/inventory';
import { Inventory } from './typings';
import { useAppDispatch } from './store';
import { debugData } from './utils/debugData';
import DragPreview from './components/utils/DragPreview';
import { fetchNui } from './utils/fetchNui';
import { useDragDropManager } from 'react-dnd';
import KeyPress from './components/utils/KeyPress';

debugData([
  {
    action: 'setupInventory',
    data: {
      leftInventory: {
        id: 'test',
        type: 'player',
        slots: 50,
        label: 'Shrey Agarwal',
        weight: 17093,
        maxWeight: 85000,
        items: [
          { slot: 1, name: 'WEAPON_ASSAULTRIFLE', weight: 4588, count: 1, metadata: { label: 'Assault Rifle', durability: 100 } },
          { slot: 2, name: 'WEAPON_PISTOL', weight: 1130, count: 1, metadata: { label: 'Pistol', durability: 100 } },
          { slot: 3, name: 'WEAPON_HEAVYPISTOL', weight: 1100, count: 1, metadata: { label: 'Heavy Pistol', durability: 100 } },
          { slot: 4, name: 'WEAPON_PERICOPISTOL', weight: 1750, count: 1, metadata: { label: 'Perico Pistol', durability: 100 } },
          { slot: 5, name: 'lockpick', weight: 160, count: 1, metadata: { label: 'Lockpick' } },
          { slot: 6, name: 'WEAPON_PISTOL', weight: 1130, count: 1, metadata: { label: 'Pistol', durability: 100 } },
          { slot: 7, name: 'WEAPON_PISTOL_MK2', weight: 1000, count: 1, metadata: { label: 'Pistol MK2', durability: 100 } },
          { slot: 8, name: 'WEAPON_SNSPISTOL', weight: 465, count: 1, metadata: { label: 'SNS Pistol', durability: 100 } },
          { slot: 9, name: 'WEAPON_HEAVYPISTOL', weight: 1100, count: 1, metadata: { label: 'Heavy Pistol', durability: 100 } },
          { slot: 10, name: 'WEAPON_REVOLVER_MK2', weight: 2600, count: 1, metadata: { label: 'Revolver MK2', durability: 100 } },
          { slot: 11, name: 'WEAPON_PISTOL50', weight: 2000, count: 1, metadata: { label: 'Pistol .50', durability: 100 } },
          { slot: 12, name: 'money', weight: 0, count: 450, metadata: { label: 'Money' } },
          { slot: 14, name: 'ammo-9', weight: 70, count: 10, metadata: { label: '9mm' } },
          // reserved quick action slots (last 5 of 50)
          { slot: 46, name: 'WEAPON_PISTOL', weight: 1130, count: 1, metadata: { label: 'Pistol', durability: 100 } },
          { slot: 47, name: 'lockpick', weight: 160, count: 1, metadata: { label: 'Lockpick' } },
          { slot: 49, name: 'ammo-9', weight: 70, count: 10, metadata: { label: '9mm' } },
        ],
      },
      rightInventory: {
        id: 'drop-1',
        type: 'newdrop',
        slots: 30,
        weight: 0,
        maxWeight: 85000,
        items: [],
      },
    },
  },
]);

const App: React.FC = () => {
  const dispatch = useAppDispatch();
  const manager = useDragDropManager();

  useNuiEvent<{
    locale: { [key: string]: string };
    items: typeof Items;
    leftInventory: Inventory;
    imagepath: string;
    hotbarSlots?: number;
  }>('init', ({ locale, items, leftInventory, imagepath, hotbarSlots }) => {
    for (const name in locale) Locale[name] = locale[name];
    for (const name in items) Items[name] = items[name];

    setImagePath(imagepath);
    setHotbarSlots(hotbarSlots);
    dispatch(setupInventory({ leftInventory }));
  });

  fetchNui('uiLoaded', {});

  useNuiEvent('closeInventory', () => {
    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  return (
    <div className="app-wrapper">
      <InventoryComponent />
      <DragPreview />
      <KeyPress />
    </div>
  );
};

addEventListener('dragstart', function (event) {
  event.preventDefault();
});

export default App;
