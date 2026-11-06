-- Charger kendaraan listrik: prop di data/chargers.lua di-spawn lokal saat player mendekat (lib.points, tanpa loop),
-- sekaligus jadi stasiun isi daya. Selama pistolnya dipegang / ditancap seseorang, model ditukar ke versi tanpa pistol.
local config = require 'config'
local state = require 'client.state'
local chargers = {}

local points = {}
local models = config.electric.chargerModel

local function spawn(point)
	local model = point.taken and models.empty or models.full

	if point.entity and DoesEntityExist(point.entity) then
		if point.model == model then return end
		DeleteEntity(point.entity)
	end

	lib.requestModel(model)

	local c = point.charger
	local obj = CreateObject(model, c.x, c.y, c.z, false, false, false)
	SetModelAsNoLongerNeeded(model)
	SetEntityHeading(obj, c.w)
	PlaceObjectOnGroundProperly(obj)
	FreezeEntityPosition(obj, true)

	point.entity, point.model = obj, model
end

local function despawn(point)
	if point.entity and DoesEntityExist(point.entity) then DeleteEntity(point.entity) end
	point.entity, point.model = nil, nil
end

if config.electric.enabled then
	local list = lib.load('data.chargers')

	for i = 1, #list do
		local c = list[i]

		points[i] = lib.points.new({
			coords = c.xyz,
			distance = 60,
			charger = c,
			electric = true,
			pumps = { c.xyz }, -- titik ambil / kembalikan pistol (client/interact.lua)
			onEnter = function(self)
				spawn(self)
				state.nearStations[self] = true
				state.nearStation = self
			end,
			onExit = function(self)
				despawn(self)
				state.nearStations[self] = nil
				state.nearStation = next(state.nearStations)
			end,
		})
	end
end

---Samakan model charger dengan selang yang sedang dipakai (dipanggil client/hose.lua)
---@param wanted table<integer, { pump: vector3, electric: boolean? }>
function chargers.refresh(wanted)
	for i = 1, #points do
		local point = points[i]
		local taken = false

		for _, w in pairs(wanted) do
			if w.electric and #(w.pump - point.coords) < 1.0 then taken = true break end
		end

		if point.taken ~= taken then
			point.taken = taken
			if point.entity then spawn(point) end
		end
	end
end

AddEventHandler('onResourceStop', function(resource)
	if resource ~= cache.resource then return end
	for i = 1, #points do despawn(points[i]) end
end)

return chargers
