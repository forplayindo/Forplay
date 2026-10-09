/**
 * Number of slots at the end of the player's inventory reserved for the quick
 * action bar. Sent by the client on init (shared.hotbarslots).
 */
export let hotbarSlots = 5;

export function setHotbarSlots(count?: number) {
  if (typeof count === 'number' && count >= 0) hotbarSlots = count;
}

/** First reserved slot number for an inventory with `slots` total slots. */
export const getFirstHotbarSlot = (slots: number) => Math.max(slots - hotbarSlots + 1, 1);
