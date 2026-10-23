-- Visual corong + selang untuk semua player yang sedang memegang selang (statebag 'fuelHose')
local config = require 'config'
local hose = {}

local NOZZLE = `prop_cs_fuel_nozle`
local active = {} -- [serverId] = { ped, pump, nozzle, rope }
local syncing = false
local localValue -- nilai selang player sendiri (tidak menunggu replikasi statebag)
local wanted = {} -- [serverId] = vector3 pompa: player yang sedang memegang selang
local SLACK = 0.4 -- kendur selang (m); panjang rope selalu = jarak pompa->corong + SLACK, supaya tidak menjuntai tembus lantai

-- pompa bensin + charger listrik
local anchorModels = {}
for i = 1, #config.pumpModels do anchorModels[#anchorModels + 1] = config.pumpModels[i] end
for i = 1, #config.electric.chargerModels do anchorModels[#anchorModels + 1] = config.electric.chargerModels[i] end

local function findPump(coords)
	for i = 1, #anchorModels do
		local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, anchorModels[i], false, false, false)
		if obj ~= 0 then return obj end
	end
end

local function clear(id)
	local h = active[id]
	if not h then return end

	if h.rope then DeleteRope(h.rope) end
	if h.nozzle and DoesEntityExist(h.nozzle) then DeleteEntity(h.nozzle) end

	active[id] = nil
end

local function attachNozzle(h)
	AttachEntityToEntity(h.nozzle, h.ped, GetPedBoneIndex(h.ped, 18905), 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, true, true, false, true, 1, true)
end

local function build(ped, pump)
	lib.requestModel(NOZZLE)

	local c = GetEntityCoords(ped)
	local nozzle = CreateObject(NOZZLE, c.x, c.y, c.z, false, true, false)
	SetModelAsNoLongerNeeded(NOZZLE)
	SetEntityCollision(nozzle, false, false)

	local h = { ped = ped, pump = pump, nozzle = nozzle }
	attachNozzle(h)
	-- rope TIDAK di-attach ke entity pompa: tarikan fisik rope bisa merusak pompa -> pompa meledak.
	-- kedua ujung dipin manual tiap frame (lihat thread di bawah).
	local pumpEntity = findPump(pump)
	local height = pumpEntity and config.pumpAnchor[GetEntityModel(pumpEntity)] or config.hose.anchorHeight
	local top = pumpEntity and GetOffsetFromEntityInWorldCoords(pumpEntity, 0.0, 0.0, height)
		or pump + vec3(0.0, 0.0, height)

	RopeLoadTextures()
	local timeout = GetGameTimer() + 2000
	while not RopeAreTexturesLoaded() and GetGameTimer() < timeout do Wait(0) end

	local tip = GetOffsetFromEntityInWorldCoords(nozzle, 0.0, -0.033, -0.195)
	local length = #(top - tip) + SLACK
	local rope = AddRope(top.x, top.y, top.z, 0.0, 0.0, 0.0, length, 1, config.hose.length + SLACK, 0.5, 1.0, false, false, false, 1.0, false)

	ActivatePhysics(rope)
	h.rope, h.top = rope, top

	return h
end

---Cocokkan visual dengan statebag player di sekitar (dipanggil berkala & saat selang lokal berubah)
local syncOnce

function hose.sync()
	if syncing then return end
	syncing = true

	local ok, err = pcall(syncOnce)
	if not ok then print(('[ox_fuel] error selang: %s'):format(err)) end

	syncing = false
end

function syncOnce()
	local myCoords = GetEntityCoords(cache.ped)

	for id, pump in pairs(wanted) do
		local player = GetPlayerFromServerId(id)
		local ped = player ~= -1 and GetPlayerPed(player) or 0
		local h = active[id]

		if ped ~= 0 and DoesEntityExist(ped) and #(GetEntityCoords(ped) - myCoords) < 80.0 then
			if not h or h.ped ~= ped or h.pump ~= pump or not DoesEntityExist(h.nozzle) then
				clear(id)
				active[id] = build(ped, pump)
			end
		elseif h then
			clear(id) -- jauh / keluar jangkauan; dibuat lagi saat mendekat
		end
	end

	for id in pairs(active) do
		if not wanted[id] then clear(id) end
	end
end

-- Loop hanya hidup selama ada player yang memegang selang. Tidak ada selang = tidak ada loop sama sekali.
local syncLoop, ropeLoop = false, false

local function startRopeLoop()
	if ropeLoop then return end
	ropeLoop = true

	-- panjang rope mengikuti jarak, kedua ujung dipin tiap frame
	CreateThread(function()
		while next(active) do
			for _, h in pairs(active) do
				if h.rope and DoesEntityExist(h.nozzle) then
					local tip = GetOffsetFromEntityInWorldCoords(h.nozzle, 0.0, -0.033, -0.195)
					RopeForceLength(h.rope, #(h.top - tip) + SLACK)

					local last = GetRopeVertexCount(h.rope) - 1
					PinRopeVertex(h.rope, 0, h.top.x, h.top.y, h.top.z)
					if last > 0 then PinRopeVertex(h.rope, last, tip.x, tip.y, tip.z) end
				end
			end
			Wait(0)
		end

		ropeLoop = false
	end)
end

local function startSyncLoop()
	if syncLoop then return end
	syncLoop = true

	CreateThread(function()
		while next(wanted) or next(active) do
			hose.sync()
			if next(active) then startRopeLoop() end
			Wait(500)
		end

		syncLoop = false
	end)
end

---@param id integer server id
---@param value table? { x, y, z } pompa, nil = selang dikembalikan
local function setWanted(id, value)
	wanted[id] = value and vec3(value[1], value[2], value[3]) or nil
	startSyncLoop()
end

-- player lain ambil / kembalikan selang. Server id dibaca dari nama bag ("player:12"),
-- jadi tetap tercatat walau player itu belum masuk jangkauan.
AddStateBagChangeHandler('fuelHose', nil, function(bagName, _, value)
	local id = tonumber(bagName:match('^player:(%d+)$'))
	if not id or id == cache.serverId then return end
	setWanted(id, value)
end)

-- resource (re)start: catat player yang sudah memegang selang
CreateThread(function()
	local players = GetActivePlayers()

	for i = 1, #players do
		local id = GetPlayerServerId(players[i])
		local value = id ~= cache.serverId and Player(id).state.fuelHose
		if value then setWanted(id, value) end
	end
end)

---@param pump vector3?
function hose.setLocal(pump)
	localValue = pump and { pump.x, pump.y, pump.z } or nil
	LocalPlayer.state:set('fuelHose', localValue, true)
	setWanted(cache.serverId, localValue)

	-- tunggu sync lain (yang mungkin sedang load model/rope) selesai, lalu sync langsung
	local timeout = GetGameTimer() + 3000
	while syncing and GetGameTimer() < timeout do Wait(0) end
	hose.sync()
	if next(active) then startRopeLoop() end
end

AddEventHandler('onResourceStop', function(resource)
	if resource ~= cache.resource then return end
	for id in pairs(active) do clear(id) end
	LocalPlayer.state:set('fuelHose', nil, true)
end)

return hose
