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

-- charger kendaraan listrik: client/chargers.lua (posisi di data/chargers.lua)
