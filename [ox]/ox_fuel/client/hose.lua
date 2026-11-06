-- Visual corong + selang untuk semua player yang sedang memakai selang (statebag 'fuelHose')
-- statebag: { pump = { x, y, z }, electric = boolean?, plug = netId kendaraan? } (plug = corong tertancap di kendaraan)
local config = require 'config'
local plug = require 'client.plug'
local chargers = require 'client.chargers'
local hose = {}

local active = {} -- [serverId] = { ped, pump, kind, plug, nozzle, rope, top }
local syncing = false
local wanted = {} -- [serverId] = { pump, electric, plug }: player yang sedang memakai selang
local SLACK = 0.4 -- kendur selang (m); panjang rope selalu = jarak pompa->corong + SLACK, supaya tidak menjuntai tembus lantai

-- pompa bensin + charger listrik
local anchorModels = {}
for i = 1, #config.pumpModels do anchorModels[#anchorModels + 1] = config.pumpModels[i] end
anchorModels[#anchorModels + 1] = config.electric.chargerModel.full
anchorModels[#anchorModels + 1] = config.electric.chargerModel.empty

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

local function plugVehicle(netId)
	if not netId or not NetworkDoesEntityExistWithNetworkId(netId) then return end
	local vehicle = NetworkGetEntityFromNetworkId(netId)
	return vehicle ~= 0 and DoesEntityExist(vehicle) and vehicle or nil
end

---Corong di kendaraan (tertancap) atau di tangan
local function attachNozzle(h)
	DetachEntity(h.nozzle, false, false)

	local vehicle = plugVehicle(h.plug)
	if vehicle then return plug.attach(h.nozzle, vehicle, h.kind) end

	local o = plug.hand(h.kind)
	AttachEntityToEntity(h.nozzle, h.ped, GetPedBoneIndex(h.ped, 18905), o[1], o[2], o[3], o[4], o[5], o[6], true, true, false, true, o[7] or 1, true)
end

local function tipOf(h)
	local tip = config.nozzles[h.kind].tip
	return GetOffsetFromEntityInWorldCoords(h.nozzle, tip.x, tip.y, tip.z)
end

local function build(ped, w)
	local kind = w.electric and 'electric' or 'petrol'
	local model = config.nozzles[kind].model
	lib.requestModel(model)

	local c = w.pump
	local nozzle = CreateObject(model, c.x, c.y, c.z, false, true, false)
	SetModelAsNoLongerNeeded(model)
	SetEntityCollision(nozzle, false, false)

	local h = { ped = ped, pump = w.pump, kind = kind, plug = w.plug, nozzle = nozzle }
	attachNozzle(h)
	-- rope TIDAK di-attach ke entity pompa: tarikan fisik rope bisa merusak pompa -> pompa meledak.
	-- kedua ujung dipin manual tiap frame (lihat thread di bawah).
	local pumpEntity = findPump(w.pump)
	local anchor = pumpEntity and config.pumpAnchor[GetEntityModel(pumpEntity)] or config.hose.anchorHeight
	local top

	if not pumpEntity then
		top = w.pump + vec3(0.0, 0.0, anchor)
	elseif type(anchor) == 'vector3' then
		top = GetOffsetFromEntityInWorldCoords(pumpEntity, anchor.x, anchor.y, anchor.z)
	else
		top = GetOffsetFromEntityInWorldCoords(pumpEntity, 0.0, 0.0, anchor)
	end

	RopeLoadTextures()
	local timeout = GetGameTimer() + 2000
	while not RopeAreTexturesLoaded() and GetGameTimer() < timeout do Wait(0) end

	local length = #(top - tipOf(h)) + SLACK
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
	-- charger yang pistolnya sedang dipakai -> model tanpa pistol (sebelum build, supaya anchor selang ketemu)
	chargers.refresh(wanted)

	local myCoords = GetEntityCoords(cache.ped)

	for id, w in pairs(wanted) do
		local player = GetPlayerFromServerId(id)
		local ped = player ~= -1 and GetPlayerPed(player) or 0
		local h = active[id]
		local plugged = plugVehicle(w.plug)
		-- corong tertancap tetap terlihat walau pemiliknya pergi jauh; di tangan butuh ped-nya
		local visible = #(w.pump - myCoords) < 80.0 and (plugged or (ped ~= 0 and DoesEntityExist(ped)))

		if visible then
			if not h or h.pump ~= w.pump or h.kind ~= (w.electric and 'electric' or 'petrol') or not DoesEntityExist(h.nozzle)
				or (not plugged and h.ped ~= ped) then
				clear(id)
				active[id] = build(ped, w)
			elseif h.plug ~= w.plug or h.ped ~= ped then
				h.plug, h.ped = w.plug, ped
				attachNozzle(h)
			end
		elseif h then
			clear(id) -- jauh / keluar jangkauan; dibuat lagi saat mendekat
		end
	end

	for id in pairs(active) do
		if not wanted[id] then clear(id) end
	end
end

-- Loop hanya hidup selama ada player yang memakai selang. Tidak ada selang = tidak ada loop sama sekali.
local syncLoop, ropeLoop = false, false

local function startRopeLoop()
	if ropeLoop then return end
	ropeLoop = true

	-- panjang rope mengikuti jarak, kedua ujung dipin tiap frame
	CreateThread(function()
		while next(active) do
			for _, h in pairs(active) do
				if h.rope and DoesEntityExist(h.nozzle) then
					local tip = tipOf(h)
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
		repeat
			hose.sync()
			if next(active) then startRopeLoop() end
			Wait(500)
		until not next(wanted) and not next(active)

		hose.sync() -- terakhir: kembalikan model charger
		syncLoop = false
	end)
end

---@param id integer server id
---@param value table? statebag fuelHose, nil = selang dikembalikan
local function setWanted(id, value)
	local p = type(value) == 'table' and value.pump

	if type(p) == 'table' and tonumber(p[1]) and tonumber(p[2]) and tonumber(p[3]) then
		wanted[id] = { pump = vec3(p[1], p[2], p[3]), electric = value.electric or nil, plug = tonumber(value.plug) }
	else
		wanted[id] = nil
	end
	startSyncLoop()
end

-- player lain ambil / tancap / kembalikan selang. Server id dibaca dari nama bag ("player:12"),
-- jadi tetap tercatat walau player itu belum masuk jangkauan.
AddStateBagChangeHandler('fuelHose', nil, function(bagName, _, value)
	local id = tonumber(bagName:match('^player:(%d+)$'))
	if not id or id == cache.serverId then return end
	setWanted(id, value)
end)

-- resource (re)start: catat player yang sudah memakai selang
CreateThread(function()
	local players = GetActivePlayers()

	for i = 1, #players do
		local id = GetPlayerServerId(players[i])
		local value = id ~= cache.serverId and Player(id).state.fuelHose
		if value then setWanted(id, value) end
	end
end)

---Pistol charger di titik ini sedang dipakai player lain
---@param pump vector3
function hose.takenByOther(pump)
	for id, w in pairs(wanted) do
		if id ~= cache.serverId and #(w.pump - pump) < 1.0 then return true end
	end
	return false
end

---@param pump vector3? nil = selang dikembalikan
---@param electric boolean?
---@param plugNet integer? netId kendaraan tempat corong tertancap
function hose.setLocal(pump, electric, plugNet)
	local value = pump and { pump = { pump.x, pump.y, pump.z }, electric = electric or nil, plug = plugNet } or nil
	LocalPlayer.state:set('fuelHose', value, true)
	setWanted(cache.serverId, value)

	-- tunggu sync lain (yang mungkin sedang load model/rope) selesai, lalu sync langsung
	local timeout = GetGameTimer() + 3000
	while syncing and GetGameTimer() < timeout do Wait(0) end
	hose.sync()
	if next(active) then startRopeLoop() end
end

-- /coloktes (config.plugDebug): tempel ulang corong sendiri dengan nilai baru
AddEventHandler('ox_fuel:plugDebug', function()
	local h = active[cache.serverId]
	if h and DoesEntityExist(h.nozzle) then attachNozzle(h) end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= cache.resource then return end
	for id in pairs(active) do clear(id) end
	LocalPlayer.state:set('fuelHose', nil, true)
end)

return hose
