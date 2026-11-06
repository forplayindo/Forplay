# Accessory fitting

Restart `electus_pets` after installing the attachment changes. Props now use full ped rotation, reject missing bones, and keep separate fits for each animal model and accessory. Existing offsets and rotation order are preserved; custom fits can override them.

To adjust a hat, bag, glasses, or another supported prop in game:

1. Equip the accessory on your pet and stand within 3 metres of it.
2. Run `/petfit` with an account allowed to use `command.petfit`.
3. Select the accessory. Adjust position in metres and rotation in degrees; submitting an adjustment previews it immediately. Offsets follow the selected bone's axes, which differ between animals.
4. Use **Save for this animal model** when it fits. Everyone sees the saved placement, including players joining later. **Cancel and revert**, or Escape from the fitting menu, discards unsaved changes.

The permission can be granted to your existing admin group in `server.cfg`, for example:

```cfg
add_ace group.admin command.petfit allow
```

Saves are stored in `data/accessory_fits.json`; preserve this file when updating the resource. A saved fit affects only that item on that exact animal model. Other animal models keep their own placements. The fitting tool lists equipped prop accessories only; built-in component collars have no object offsets to adjust.

Advanced settings accept a bone ID or name and an Euler rotation order. Use a head bone for a hat and a spine bone for a back-mounted bag, then recalibrate the offsets after changing bones. Missing bones are rejected instead of attaching a prop to the animal's centre. Full ped rotation is enabled by default so pitch and positive roll work.

The tool works for configured custom animals too, once their item definitions exist in `Config.AddonAccessories`. It does not automatically add support for an accessory to every animal. Husky defaults currently include headwear, glasses and neckwear; bags require an explicit husky attachment definition and an in-game fit.

The shared attachment behavior is covered by mocked-native tests. Exact appearance, clipping and movement still require an in-game visual check for each model/item combination.
