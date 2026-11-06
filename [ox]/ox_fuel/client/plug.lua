-- Titik tancap corong / pistol charger di kendaraan (gaya lc_fuel):
-- tulang tutup tangki kendaraan + offset per model (data/plugs.lua), selain itu config.plugDefault.
local config = require 'config'
local plug = {}

local BONES = { 'petrolcap', 'petroltank', 'petroltank_l', 'petroltank_r', 'wheel_lr', 'wheel_lf', 'engine', 'chassis_dummy' }

local params = {}
for name, data in pairs(lib.load('data.plugs')) do params[joaat(name)] = data end

-- nilai hasil /coloktes (hanya saat config.plugDebug), mengalahkan config
local debugHand, debugRot = {}, {}

---@param kind 'petrol' | 'electric'
function plug.hand(kind)
	return debugHand[kind] or config.nozzles[kind].hand
end

---Titik tancap dalam koordinat kendaraan
---@param vehicle integer
---@param kind 'petrol' | 'electric'
---@return vector3 offset, vector3 rotation, number distance jarak player ke titik tancap
function plug.get(vehicle, kind)
	local data = params[GetEntityModel(vehicle)]
	local distance = data and data.distance or config.plugDefault.distance
	local rot = debugRot[kind] or config.nozzles[kind].rot
	local base

	for i = 1, #BONES do
		local bone = GetEntityBoneIndexByName(vehicle, BONES[i])
		if bone ~= -1 then
			local pos = GetWorldPositionOfEntityBone(vehicle, bone)
			base = GetOffsetFromEntityGivenWorldCoords(vehicle, pos.x, pos.y, pos.z)
			break
		end
	end

	if not base then
		-- kendaraan tanpa tulang yang dikenal: belakang kiri, setengah tinggi body
		local min, max = GetModelDimensions(GetEntityModel(vehicle))
		return vec3(min.x, min.y * 0.6, (min.z + max.z) / 2), rot, distance
	end

	local offset, extra = config.plugDefault.nozzleOffset, nil

	if data then
		offset, extra = data.nozzleOffset, data.nozzleRotation
	elseif base.x > 0 then
		-- tutup tangki di sisi kanan: cerminkan offset, corong menghadap ke kiri
		offset = { forward = offset.forward, right = -offset.right, up = offset.up }
		extra = { x = 0, y = 0, z = 180 }
	end

	if extra then rot += vec3(extra.x or 0, extra.y or 0, extra.z or 0) end

	return base + vec3(offset.right, offset.forward, offset.up), rot, distance
end

---@return vector3 world, number distance
function plug.world(vehicle, kind)
	local offset, _, distance = plug.get(vehicle, kind)
	return GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, offset.z), distance
end

---Putar vektor dengan rotasi urutan 2 (Z * X * Y), sama dengan GetEntityRotation / AttachEntityToEntity order 2
local function rotate(v, r)
	local x, y, z = math.rad(r.x), math.rad(r.y), math.rad(r.z)
	local cy, sy = math.cos(y), math.sin(y)
	v = vec3(v.x * cy + v.z * sy, v.y, -v.x * sy + v.z * cy)
	local cx, sx = math.cos(x), math.sin(x)
	v = vec3(v.x, v.y * cx - v.z * sx, v.y * sx + v.z * cx)
	local cz, sz = math.cos(z), math.sin(z)
	return vec3(v.x * cz - v.y * sz, v.x * sz + v.y * cz, v.z)
end

---Tempel corong ke kendaraan (ikut bergerak bersama kendaraan)
function plug.attach(nozzle, vehicle, kind)
	local offset, rot = plug.get(vehicle, kind)
	local shift = config.nozzles[kind].shift
	-- colokan lebih panjang dari prop lc_fuel: mundurkan corong searah colokan supaya tidak masuk ke body
	if shift then offset -= rotate(shift, rot) end
	AttachEntityToEntity(nozzle, vehicle, 0, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
end

if not config.plugDebug then return plug end

-- Kalibrasi (config.plugDebug = true), hanya mengubah tampilan lokal:
--  /coloktes tangan <bensin|listrik> x y z rx ry rz  -> posisi corong di tangan
--  /coloktes putar <bensin|listrik> rx ry rz         -> rotasi corong saat tertancap (sisi kiri)
--  /coloktes mobil forward right up [rz]             -> titik tancap model kendaraan terdekat
--  /coloktes                                         -> tampilkan nilai sekarang
local KIND = { bensin = 'petrol', listrik = 'electric' }

local function nearestVehicle()
	local coords = GetEntityCoords(cache.ped)
	local vehicle = lib.getClosestVehicle(coords, 5.0, false)
	return vehicle
end

RegisterCommand('coloktes', function(_, args)
	local mode = args[1]
	local n = function(i) return tonumber(args[i]) or 0.0 end

	if mode == 'tangan' and KIND[args[2]] then
		local kind = KIND[args[2]]
		debugHand[kind] = { n(3), n(4), n(5), n(6), n(7), n(8), config.nozzles[kind].hand[7] }
		print(('[ox_fuel] nozzles.%s.hand = { %.3f, %.3f, %.3f, %.1f, %.1f, %.1f },'):format(kind, table.unpack(debugHand[kind])))
	elseif mode == 'putar' and KIND[args[2]] then
		local kind = KIND[args[2]]
		debugRot[kind] = vec3(n(3), n(4), n(5))
		print(('[ox_fuel] nozzles.%s.rot = vec3(%.1f, %.1f, %.1f),'):format(kind, n(3), n(4), n(5)))
	elseif mode == 'mobil' then
		local vehicle = nearestVehicle()
		if not vehicle then return print('[ox_fuel] tidak ada kendaraan dalam 5 m') end

		local data = exports.qbx_core:GetVehiclesByHash(GetEntityModel(vehicle))
		local entry = { distance = config.plugDefault.distance, nozzleOffset = { forward = n(2), right = n(3), up = n(4) } }
		if args[5] then entry.nozzleRotation = { x = 0, y = 0, z = n(5) } end
		params[GetEntityModel(vehicle)] = entry

		print(('[ox_fuel] data/plugs.lua: ["%s"] = { distance = %.1f, nozzleOffset = { forward = %.2f, right = %.2f, up = %.2f }%s },')
			:format(data and data.model or GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower(), entry.distance, n(2), n(3), n(4),
				args[5] and (', nozzleRotation = { x = 0, y = 0, z = %d }'):format(math.floor(n(5))) or ''))
	else
		for name, kind in pairs(KIND) do
			local h, r = plug.hand(kind), debugRot[kind] or config.nozzles[kind].rot
			print(('[ox_fuel] %s: tangan { %.3f, %.3f, %.3f, %.1f, %.1f, %.1f } putar (%.1f, %.1f, %.1f)'):format(name, h[1], h[2], h[3], h[4], h[5], h[6], r.x, r.y, r.z))
		end
		return
	end

	TriggerEvent('ox_fuel:plugDebug') -- hose.lua menempel ulang corong sendiri
end, false)

return plug
