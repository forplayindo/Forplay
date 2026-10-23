local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local stations = lib.load 'data.stations'

if config.showBlips == 2 then
	for station in pairs(stations) do utils.createBlip(station) end
end

if config.ox_target and config.showBlips ~= 1 then return end

---@param point CPoint
local function onEnterStation(point)
	if config.showBlips == 1 and not point.blip then
		point.blip = utils.createBlip(point.coords)
	end

	-- interaksi pompa (client/interact.lua) hanya aktif di dekat SPBU / charger
	state.nearStations[point] = true
	state.nearStation = point
end

---@param point CPoint
local function onExitStation(point)
	if point.blip then
		point.blip = RemoveBlip(point.blip)
	end

	state.nearStations[point] = nil
	state.nearStation = next(state.nearStations)
end

for station, pumps in pairs(stations) do
	lib.points.new({
		coords = station,
		distance = 60,
		onEnter = onEnterStation,
		onExit = onExitStation,
		pumps = pumps,
	})
end

-- Stasiun charger kendaraan listrik: charger (prop bawaan GTA) dicari di sekitar titik saat player mendekat
if config.electric.enabled then
	local chargerModel = {}
	for i = 1, #config.electric.chargerModels do chargerModel[config.electric.chargerModels[i]] = true end

	local function findChargers(center)
		local found = {}
		local objects = GetGamePool('CObject')

		for i = 1, #objects do
			local obj = objects[i]
			if chargerModel[GetEntityModel(obj)] then
				local coords = GetEntityCoords(obj)
				if #(coords - center) <= config.electric.stationRadius then found[#found + 1] = coords end
			end
		end

		-- prop tidak ditemukan (map custom): pakai titik stasiun sebagai charger
		if #found == 0 then found[1] = center end
		return found
	end

	for i = 1, #config.electric.stations do
		lib.points.new({
			coords = config.electric.stations[i],
			distance = 60,
			electric = true,
			pumps = {},
			onEnter = function(point)
				point.pumps = findChargers(point.coords)
				onEnterStation(point)
			end,
			onExit = onExitStation,
		})
	end
end
