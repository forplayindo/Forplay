-- Interaksi SPBU: prompt ox_lib textUI + keybind E/G; proses pengisian tampil di hologram 3D (gaya caticus)
-- pompa: ambil selang -> dekat mobil [E] mulai isi / [E] berhenti (hologram proses) -> kembalikan selang
local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local fuel = require 'client.fuel'
local hose = require 'client.hose'
local display = require 'client.display'
local menu = require 'client.menu'
local tank = require 'shared.tank'

local actionE, actionG -- fungsi yang dijalankan saat tombol ditekan
local shownText
local warned = false
local snapTicks = 0
local fueling -- { stop: boolean, at: vector3 } saat sedang mengisi dari selang

local function rp(value)
	return locale('price', math.groupdigits(value, '.'))
end

local function setText(text)
	if text == shownText then return end
	shownText = text

	if text then lib.showTextUI(text) else lib.hideTextUI() end
end

local function takeHose(pump, electric)
	state.hose = pump
	state.hoseElectric = electric or nil
	display.prepare() -- browser hologram dimuat sekarang, siap saat mulai mengisi
	hose.setLocal(pump)
end

local function returnHose(snapped)
	local pump = state.hose
	if not pump then return end
	local electric = state.hoseElectric
	state.hose = nil
	state.hoseElectric = nil
	display.release()
	warned = false
	snapTicks = 0
	hose.setLocal(nil)

	if snapped then
		local distance = #(GetEntityCoords(cache.ped) - pump)
		print(('[ox_fuel] selang putus: jarak ke pompa %.2f m (batas %.1f)'):format(distance, config.hose.length))

		if config.hose.explode and not electric then
			-- notifikasi ledakan baru muncul setelah server konfirmasi (ox_fuel:explodePump)
			TriggerServerEvent('ox_fuel:hoseSnapped', pump)
		end

		lib.notify({ type = 'error', description = locale('hose_snapped') })
	end
end

RegisterNetEvent('ox_fuel:explodePump', function(pump)
	AddExplosion(pump.x, pump.y, pump.z + 0.5, 9, 1.0, true, false, 1.0) -- 9 = EXP_TAG_PETROL_PUMP
	lib.notify({ type = 'error', description = locale('hose_snapped_explode') })
end)

---Mobil yang body-nya paling dekat (sisi mana pun)
---@return integer? vehicle, vector3? at titik di atas body terdekat (posisi hologram)
local function getNearbyVehicle(coords, maxDistance)
	local vehicles = GetGamePool('CVehicle')
	local best, bestDistance, bestAt

	for i = 1, #vehicles do
		local vehicle = vehicles[i]

		if vehicle ~= cache.vehicle and #(coords - GetEntityCoords(vehicle)) < 10.0
			and (DoesVehicleUseFuel(vehicle) or tank.isElectric(GetEntityModel(vehicle))) then
			local min, max = GetModelDimensions(GetEntityModel(vehicle))
			local rel = GetOffsetFromEntityGivenWorldCoords(vehicle, coords.x, coords.y, coords.z)
			local cx = math.clamp(rel.x, min.x, max.x)
			local cy = math.clamp(rel.y, min.y, max.y)
			local distance = #(vec2(rel.x, rel.y) - vec2(cx, cy))

			if distance <= maxDistance and (not bestDistance or distance < bestDistance) then
				best, bestDistance = vehicle, distance
				bestAt = GetOffsetFromEntityInWorldCoords(vehicle, cx, cy, max.z + 0.15)
			end
		end
	end

	return best, bestAt
end

local function playHoseAnim()
	local anim = config.hose.anim
	lib.requestAnimDict(anim.dict)
	TaskPlayAnim(cache.ped, anim.dict, anim.clip, 2.0, 2.0, -1, anim.flag or 1, 0, false, false, false)
	RemoveAnimDict(anim.dict)

	if not anim.freeze then return end

	-- tunggu anim jalan, lalu bekukan pose (tangan yang bebas tidak ikut bergerak)
	local timeout = GetGameTimer() + 1000
	while not IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) and GetGameTimer() < timeout do Wait(0) end

	SetEntityAnimCurrentTime(cache.ped, anim.dict, anim.clip, anim.frame or 0.0)
	SetEntityAnimSpeed(cache.ped, anim.dict, anim.clip, 0.0)
end

---Isi bensin dari selang: menu (jenis BBM, liter, Cash/Transfer) -> isi dengan hologram.
---[E] berhenti di tengah. Bayar dihitung server saat selesai, sesuai liter yang benar-benar masuk.
local function fuelWithHose(vehicle, at)
	if fueling then return end

	-- kabel charger hanya untuk mobil listrik, selang bensin hanya untuk mobil bensin
	local electric = tank.isElectric(GetEntityModel(vehicle))

	if electric ~= (state.hoseElectric or false) then
		return lib.notify({ type = 'error', description = locale(electric and 'is_electric' or 'not_electric') })
	end

	local netId = NetworkGetNetworkIdFromEntity(vehicle)
	local quote = lib.callback.await('ox_fuel:quote', false, netId)

	if not quote or quote.error then
		return lib.notify({ type = 'error', description = quote and quote.error or locale('vehicle_far') })
	end

	if quote.free < 1 then
		return lib.notify({ type = 'error', description = locale('tank_full') })
	end

	local choice = menu.open(quote)
	if not choice or not state.hose then return end

	local order = lib.callback.await('ox_fuel:start', false, netId, choice.type, choice.liters, choice.method)

	if not order or order.error then
		return lib.notify({ type = 'error', description = order and order.error or locale('vehicle_far') })
	end

	fueling = { stop = false, at = at }
	actionE = function() fueling.stop = true end
	state.isFueling = true

	TaskTurnPedToFaceEntity(cache.ped, vehicle, 800)
	Wait(800)
	playHoseAnim()

	local filled = 0.0
	local vehicleStart = GetEntityCoords(vehicle)
	local status, statusState = locale('holo_done'), 'done'
	local fillingText = locale(electric and 'holo_charging' or 'holo_filling')

	local function push(text, kind)
		display.update({
			title = electric and 'CHARGER' or 'SPBU',
			label = electric and 'DAYA' or 'BENSIN',
			unit = electric and 'kWh' or 'L',
			liters = filled,
			total = math.ceil(filled * order.price),
			percent = math.min(100, order.startPercent + filled / order.size * 100),
			status = text,
			state = kind,
		})
	end

	display.show(at + vec3(0.0, 0.0, 0.45))
	push(fillingText)

	while not fueling.stop do
		Wait(config.refillTick)

		if fueling.stop then break end

		if not DoesEntityExist(vehicle) or #(GetEntityCoords(vehicle) - vehicleStart) > 0.5 or not state.hose
			or cache.vehicle or IsEntityDead(cache.ped) then
			status, statusState = locale('holo_stopped'), 'warn'
			break
		end

		filled = math.min(filled + order.rate, order.liters)

		if filled >= order.liters then
			if order.startPercent + filled / order.size * 100 >= 99.9 then status = locale('holo_full') end
			break
		end

		push(fillingText)
	end

	push(status, statusState)
	display.hide(2500)
	StopAnimTask(cache.ped, config.hose.anim.dict, config.hose.anim.clip, 1.0)

	fueling = nil
	state.isFueling = false

	TriggerServerEvent('ox_fuel:finish', filled)
end

---@return vector3? pump, boolean? electric
local function getNearestPump(coords)
	for station in pairs(state.nearStations) do
		for i = 1, #station.pumps do
			local pump = station.pumps[i]
			if #(coords - pump) <= config.hose.pumpDistance then return pump, station.electric end
		end
	end
end

---@return string?, function?, function? teks prompt, aksi E, aksi G
local function getAction()
	if fueling then
		return locale(state.hoseElectric and 'charger_stop' or 'hose_stop'), function() fueling.stop = true end
	end

	local coords = GetEntityCoords(cache.ped)

	if state.hose then
		if cache.vehicle or IsEntityDead(cache.ped) then
			return returnHose(false)
		end

		local pumpDistance = #(coords - state.hose)

		-- harus lewat batas 2 cek berturut-turut (±400ms) baru dianggap putus
		if pumpDistance > config.hose.length then
			snapTicks += 1
			if snapTicks >= 2 then return returnHose(true) end
			return
		end

		snapTicks = 0

		if pumpDistance > config.hose.warnDistance then
			if not warned then
				warned = true
				lib.notify({ type = 'warning', description = locale('hose_warning') })
			end
		else
			warned = false
		end

		if state.isFueling or lib.progressActive() then return end

		-- jangan oper returnHose langsung: CreateThread mengirim argumen -> terbaca 'snapped' -> meledak
		local nearPump = pumpDistance <= config.hose.pumpDistance
		local vehicle, at = getNearbyVehicle(coords, config.hose.capDistance)
		local doReturn = function() returnHose(false) end

		local prefix = state.hoseElectric and 'charger_' or 'hose_'

		-- mobil parkir mepet pompa: dekat keduanya -> E isi bensin, G kembalikan selang
		if vehicle then
			local doFuel = function() fuelWithHose(vehicle, at) end
			if nearPump then return locale(prefix .. 'fuel_or_return'), doFuel, doReturn end
			return locale(prefix .. 'fuel'), doFuel
		end

		if nearPump then return locale(prefix .. 'return'), doReturn end

		return
	end

	if cache.vehicle or state.isFueling or lib.progressActive() then return end

	local pump, electric = getNearestPump(coords)

	if pump and electric then
		return locale('charger_take'), function() takeHose(pump, true) end
	end

	if pump then
		if state.petrolCan then
			return locale('petrolcan_refill_help', rp(config.petrolCan.refillPrice)), function()
				if utils.getMoney() < config.petrolCan.refillPrice then
					return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
				end

				fuel.getPetrolCan(pump, true)
			end
		end

		if config.petrolCan.enabled then
			return locale('hose_take_or_buy', rp(config.petrolCan.price)), function() takeHose(pump) end, function()
				if utils.getMoney() < config.petrolCan.price then
					return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
				end

				fuel.getPetrolCan(pump, false)
			end
		end

		return locale('hose_take'), function() takeHose(pump) end
	end

	if state.petrolCan then
		local vehicle = getNearbyVehicle(coords, 1.8)

		if vehicle and not tank.isElectric(GetEntityModel(vehicle)) then
			return locale('petrolcan_fuel_help'), function() fuel.startFueling(vehicle, false) end
		end
	end
end

local function run(fn)
	if fn then CreateThread(fn) end
end

lib.addKeybind({
	name = 'ox_fuel_interact',
	description = 'SPBU: ambil/kembalikan selang, mulai/berhenti isi bensin',
	defaultKey = 'E',
	onPressed = function() run(actionE) end,
})

lib.addKeybind({
	name = 'ox_fuel_buycan',
	description = 'SPBU: beli jerigen / kembalikan selang',
	defaultKey = 'G',
	onPressed = function() run(actionG) end,
})

CreateThread(function()
	local nextCheck = 0

	while true do
		if fueling or state.hose or state.petrolCan or state.nearStation then
			local now = GetGameTimer()

			-- cek kondisi tiap 200ms
			if now >= nextCheck then
				nextCheck = now + 200

				local ok, text, e, g = pcall(getAction)
				if not ok then
					print(('[ox_fuel] error interaksi: %s'):format(text))
					text, e, g = nil, nil, nil
				end

				setText(text)
				actionE, actionG = e, g
			end

			if state.hose then
				-- pegang corong: tidak bisa masuk kendaraan / pakai senjata
				DisableControlAction(0, 23, true)  -- masuk kendaraan
				DisableControlAction(0, 24, true)  -- tembak
				DisableControlAction(0, 25, true)  -- bidik
				DisableControlAction(0, 37, true)  -- weapon wheel
				DisablePlayerFiring(cache.playerId, true)
			end

			if fueling then
				-- diam selama mengisi; berhenti dengan [E]
				DisableControlAction(0, 30, true)  -- gerak kiri/kanan
				DisableControlAction(0, 31, true)  -- gerak maju/mundur
				DisableControlAction(0, 21, true)  -- lari
				DisableControlAction(0, 22, true)  -- lompat
			end

			Wait((state.hose or fueling) and 0 or 200)
		else
			setText(nil)
			actionE, actionG = nil, nil
			Wait(500)
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == cache.resource and shownText then lib.hideTextUI() end
end)
