---@class State
---@field petrolCan SlotWithItem?
---@field isFueling boolean
---@field nearestPump vector3?
---@field lastVehicle number?
---@field hose vector3? pompa asal corong yang sedang dipegang
---@field nearStation CPoint? salah satu stasiun terdekat (penanda ada stasiun di sekitar)
---@field nearStations table<CPoint, true> semua stasiun (bensin/charger) di sekitar
---@field hoseElectric boolean? selang yang dipegang = kabel charger
local state = {
	isFueling = false,
	nearStations = {},
	lastVehicle = cache.vehicle or GetPlayersLastVehicle()
}

if state.lastVehicle == 0 then state.lastVehicle = nil end

---@param data? SlotWithItem
local function setPetrolCan(data)
	state.petrolCan = data?.name == 'WEAPON_PETROLCAN' and data or nil
end

setPetrolCan(exports.ox_inventory:getCurrentWeapon())

AddEventHandler('ox_inventory:currentWeapon', setPetrolCan)

return state
