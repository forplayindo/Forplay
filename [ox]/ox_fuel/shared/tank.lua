-- Ukuran tangki/baterai & jenis BBM, dipakai client dan server supaya hitungannya sama
local config = require 'config'
local tank = {}

local typeById = {}
for i = 1, #config.fuelTypes do typeById[config.fuelTypes[i].id] = config.fuelTypes[i] end

-- "jenis BBM" untuk kendaraan listrik (harga per kWh)
tank.electricType = { id = 'listrik', label = 'Listrik', price = config.electric.price, color = '#facc15' }

---@param id string
function tank.fuelType(id)
	return typeById[id]
end

local function vehicleData(model)
	return exports.qbx_core:GetVehiclesByHash(model)
end

---@param model number
---@return boolean
function tank.isElectric(model)
	if not config.electric.enabled then return false end
	local data = vehicleData(model)
	return data and config.electric.models[data.model] or false
end

---@param model number
---@return boolean
function tank.isPerformance(model)
	local data = vehicleData(model)
	return data and config.performanceCategories[data.category] or false
end

---Kapasitas: liter (bensin) atau kWh (listrik)
---@param model number hash model kendaraan
---@return number
function tank.size(model)
	local data = vehicleData(model)
	if not data then return config.tankDefault end

	if config.electric.enabled and config.electric.models[data.model] then
		return config.electric.batteryModels[data.model] or config.electric.batteryDefault
	end

	return config.tankModels[data.model] or config.tankSizes[data.category] or config.tankDefault
end

return tank
