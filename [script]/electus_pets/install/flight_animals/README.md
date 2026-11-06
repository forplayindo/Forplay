# Bundled horse and donkey models

Source: [elajnabe/flight-animals](https://github.com/elajnabe/flight-animals), commit
`47a09e49ad2aa545831cd6c12cff55d40a7bce54`.
The upstream resource credits DevTheBully. Its supplied license is preserved in `LICENSE`.

This resource includes only Donkey, Fullhorse, Rangehorse, and Younghorse (16 original
model files). `data/flight_animals_peds.meta` is an edited copy of upstream `peds.meta`,
filtered to these four definitions. No wildlife spawning scripts are included.
`SOURCE.json` records the original Git blob checksums and local SHA-256 checksums.

The existing farm shop, variations, riding offsets, prices, and status system use these
exact model names. Restart electus_pets after installing these files. Do not register
these same four models from another active resource at the same time.
Controlled riding is enabled in `config/config.lua`: the rider stays attached to the
original animal, which keeps its network ID and health/status tracking while mounted.

Upstream metadata assigns the DEER movement set to these models. They reuse GTA animal
movement; custom horse animations, dog fetch, dog petting scenes, and accessories need
separate compatible animation/attachment definitions. Other animals in the upstream pack
have not been installed or enabled by this change.

To verify or repeat the import, run `python install/import_flight_equines.py`.
It downloads only the pinned model files, metadata, and license, checks each Git blob,
and refuses to replace different existing files.
