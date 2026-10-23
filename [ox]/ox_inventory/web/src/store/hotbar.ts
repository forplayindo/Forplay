import type { Slot } from '../typings';

/**
 * Player inventory layout (sent by the client on init):
 *   [ regular grid slots ][ hotbar slots ][ key ring slots ]
 * hotbarSlots = shared.hotbarslots, keySlots = shared.keyslots (only `keyItem` may be stored there).
 */
export let hotbarSlots = 5;
export let keySlots = 0;
export let keyItem = 'car_key';

export function setHotbarSlots(count?: number) {
  if (typeof count === 'number' && count >= 0) hotbarSlots = count;
}

export function setKeyRing(count?: number, item?: string) {
  if (typeof count === 'number' && count >= 0) keySlots = count;
  if (item) keyItem = item;
}

/** First reserved slot number for an inventory with `slots` total slots. */
export const getFirstHotbarSlot = (slots: number) => Math.max(slots - keySlots - hotbarSlots + 1, 1);

/** First key ring slot number for an inventory with `slots` total slots. */
export const getFirstKeySlot = (slots: number) => Math.max(slots - keySlots + 1, 1);

export const getGridItems = <T extends Slot>(items: T[]) => items.slice(0, Math.max(items.length - keySlots - hotbarSlots, 0));

export const getHotbarItems = <T extends Slot>(items: T[]) =>
  items.slice(Math.max(items.length - keySlots - hotbarSlots, 0), Math.max(items.length - keySlots, 0));

export const getKeyItems = <T extends Slot>(items: T[]) => (keySlots > 0 ? items.slice(-keySlots) : []);

/** Whether `itemName` may be put in `slot` of the player's inventory (mirrors shared.slotAccepts on the server). */
export const playerSlotAccepts = (slots: number, slot: number, itemName?: string) =>
  keySlots <= 0 || slot < getFirstKeySlot(slots) || itemName === keyItem;
