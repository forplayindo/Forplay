ELECTUS PETS - ESX / QBCore / Qbox

FRAMEWORK AND START ORDER
Config.Framework supports auto, esx, qb and qbx (qbox is an alias).
Auto prefers qbx_core, then the configured QBCore resource, then es_extended.
Qbox uses native qbx_core exports; the QB compatibility bridge is not required.
Keep CustomStringQBExport set to your QBCore resource name when using qb.

Start oxmysql, ox_lib, your framework, inventory and target before electus_pets.
OneSync is required for server-created pet entities.
The four configured equines (Donkey, Fullhorse, Rangehorse, Younghorse) are now bundled
under stream/flight_animals, with their metadata registered in fxmanifest.lua.
They are sold by the farm shop. Source, version and license: install/flight_animals/README.md.
Controlled riding is enabled so the original networked animal and its status tracking
remain active while mounted. Do not also stream these four names from another resource.
Config.Framework defaults to auto; inventory and target remain ox_inventory and ox_target.
Use qb-inventory and qb-target on a QBCore installation if desired.

SERVER FILES
server/frameworks/*.lua: selected framework's player, character, job and money adapter.
server/inventory.lua: inventory bridge.
server/main.lua: callback bridge, helpers and automatic schema creation.
escrowed/server/*.lua: readable replacement gameplay implementation, loaded by the manifest.
These are newly implemented server files, not recovered vendor escrow source.
Existing data in electus_pets, electus_pet_houses and electus_pet_friends is retained.
install.sql can also provision these tables manually.

INVENTORY SUPPORT
Supported item adapters: ox_inventory, esx (ESX only), qb (legacy QBCore player functions),
and qb-inventory (current server exports). Pet bags require ox_inventory or qb-inventory.
Vehicle sniffing supports ox_inventory, qb/qb-inventory and custom.
For custom trunks, implement Config.GetCustomVehiclePlateInventoryItems on the server.
Other inventory integrations need a server adapter before selecting them.
The 64 configured food, leash, house and shop accessory items have been merged into
this server's ox_inventory/data/items.lua. The existing water definition is preserved.
They load on the next server restart. Item icons reuse files already in ox_inventory/web/images;
the supplied pets resource has no items_img directory. Equipment and food have consume=0
because the pet menu/server handlers manage their inventory consumption.
Reusable definitions: install/ox_inventory_items.lua.
For another installation, merge these entries into the inventory's returned item table,
or run install/install_ox_items.py --inventory PATH_TO_OX/data/items.lua --apply.
The installer skips existing definitions and backs up the inventory file under install/backups.
Using the doghouse item starts placement; confirming consumes the item after server validation.
Cancelling keeps the item. Picking up an empty house returns the item.
House placement no longer charges an additional cash or bank fee.

TRUSTED SERVER EXPORTS
exports.electus_pets:GivePet(source, model, name, variation) returns success.
exports.electus_pets:AddPetXP(source, petName, amount) awards XP and skill points.
exports.electus_pets:RegisterFetchedBall(source, itemName) consumes a fetch ball before
allowing the client's giveBall event to return one. No arbitrary free item grant is exposed.
Client-provided full skill tables and free-pet debug events are not accepted.
Skill upgrades and ability unlocks spend the stored points using configured costs.

FIXES AND REMAINING LIMITATIONS
Stale pet-menu callbacks return safe responses, and delayed accessory replies cannot edit a
replacement pet. Both auto-attack buttons use the server's ability/status checks.
Emotes pause following; superseded animation loads and emote timers cannot restart old actions.
Scent learning has a bounded approach, server item/cooldown checks and confirmed persistence.
House placement cleans up after loading/request errors, cancellation and character changes.
Bag grants belong to the unlocking character and require matching routing buckets after DB waits.
Trunk searches resolve the actual vehicle/plate and require an active pet with the unlocked ability.
Qbox, QBCore and ESX use the same cancellable character setup and immediate logout cleanup.
Job updates refresh cached player data and shop access, including shops allowing several jobs.
Custom character-swap events apply to all three adapters. Delayed spawn callbacks are cancelled
on logout. Pet entities are removed by the server after their health has been captured.
Player data may be absent during character selection; adapters handle that without crashing.
Qbox clothing restoration reads the shared player data without requiring a QBCore object.
Client Lua syntax, shared pet state, public action functions, native ox_target integration,
menu capabilities, cleanup and house placement/storage contracts have been repaired.
Skill costs and ability prerequisites are enforced by the server and reflected in the UI.
Pet restoration waits for each network spawn; a failed client setup cleans up its entity.
Follow requests are idempotent and cancelled loops stop before issuing new movement tasks.
Networked pets, tasks, fetch props and petting scenes are shared by OneSync in the same
routing bucket and streaming range. Public appearance/leash records also reach late joiners.
Each observer rebuilds local accessory props and leash visuals when a pet streams in, and removes
them when it streams out or despawns. Only the server can approve leash changes.
Leashes draw a slack cord each frame without native rope attachments or repeated winding;
the networked animal follows ordinary movement tasks. Attaching a leash resumes following
from idle or emotes. Cosmetic cleanup checks object types before deleting local props.
Public updates have revisions to prevent delayed snapshots from restoring removed pets.
The server moves active pets to their owner's routing bucket when it changes.
Vehicle commands use relative door offsets, release reserved seats and resume following after exit.
Transfers validate recipient capacity and spawn the transferred pet for its new owner.
Network recovery waits are bounded, health updates reject stale revisions, and old stored pets
count toward command-house capacity. Disabled breeding no longer advances local breeding counts.
Food and water awards now use server-validated item consumption and synchronize pet status/XP.
Fetch uses prop_tennis_ball as its visible object, with WEAPON_BALL remaining the inventory
item. It does not wait for or spawn the w_am_baseball weapon model.
Other action XP, full daily-task progression and breeding remain incomplete in the supplied
implementation. Breeding confirmation is disabled. The original accessory debug editor was
placeholder code; the runtime now equips configured accessories using preserved offsets.
The full resource still requires testing inside FiveM, especially native animations, riding,
vehicle seats, network ownership and inventory behavior. Mocked tests cannot validate these.

VERIFICATION
Run python -m unittest discover -s tests -v (requires the Python lupa package).
Run node --test tests/nui.test.cjs for the browser request bridge.
NUI initialization sends only JSON-safe UI configuration and runs once on mount.
Callbacks reply on early returns and report named errors if a handler fails.
The tests use mocked FiveM/framework/database interfaces; they do not replace an in-game test.
