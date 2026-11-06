-- Interaksi SPBU / charger: prompt ox_lib textUI + keybind E/G; proses pengisian tampil di hologram 3D (gaya caticus)
-- ambil corong / pistol -> dekat tutup tangki [E] isi: corong DITANCAP ke kendaraan (gaya lc_fuel), player bebas pergi
-- -> selesai / kapan saja [E] di tutup tangki: cabut, corong kembali ke tangan -> kembalikan ke pompa / charger
local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local fuel = require 'client.fuel'
local hose = require 'client.hose'
local plug = require 'client.plug'
local display = require 'client.display'
local menu = require 'client.menu'
local tank = require 'shared.tank'

local actionE, actionG -- fungsi yang dijalankan saat tombol ditekan
local shownText
local warned = false
local snapTicks = 0
local fueling -- { stop: boolean } selama corong tertancap DAN sedang mengisi
local marker -- titik tutup tangki yang digambar saat memegang corong di dekat kendaraan
local plugged -- { vehicle, netId, pos } corong tertancap di kendaraan

local function rp(value)
	return locale('price', math.groupdigits(value, '.'))
end

local function setText(text)
	if text == shownText then return end
	shownText = text

	if text then lib.showTextUI(text) else lib.hideTextUI() end
end

local function kind()
	return state.hoseElectric and 'electric' or 'petrol'
end

local function publish()
	hose.setLocal(state.hose, state.hoseElectric, plugged and plugged.netId)
end

local function handAnim()
	lib.requestAnimDict('anim@am_hold_up@male')
	TaskPlayAnim(cache.ped, 'anim@am_hold_up@male', 'shoplift_high', 2.0, 8.0, -1, 50, 0, false, false, false)
	RemoveAnimDict('anim@am_hold_up@male')
	Wait(300)
	StopAnimTask(cache.ped, 'anim@am_hold_up@male', 'shoplift_high', 1.0)
end

local function takeHose(pump, electric)
	handAnim()
	state.hose = pump
	state.hoseElectric = electric or nil
	display.prepare() -- browser hologram dimuat sekarang, siap saat mulai mengisi
	publish()
end

local function returnHose(snapped)
	local pump = state.hose
	if not pump then return end
	local electric = state.hoseElectric
	state.hose = nil
	state.hoseElectric = nil
	plugged = nil
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

---Kendaraan yang body-nya paling dekat (sisi mana pun)
---@return integer? vehicle
local function getNearbyVehicle(coords, maxDistance)
	local vehicles = GetGamePool('CVehicle')
	local best, bestDistance

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
			end
		end
	end

	return best
end

---Corong lepas dari kendaraan yang bergerak / hilang -> kembali ke pompa
local function plugLost()
	return not DoesEntityExist(plugged.vehicle) or #(GetEntityCoords(plugged.vehicle) - plugged.pos) > 0.5
end

local function ripOff()
	lib.notify({ type = 'error', description = locale(state.hoseElectric and 'charger_ripped' or 'hose_ripped') })
	returnHose(false)
end

---Isi dari selang: menu (jenis BBM / mode charger, jumlah, Cash/Transfer) -> corong ditancap -> mengisi sendiri.
---Bayar dihitung server saat selesai, sesuai yang benar-benar masuk.
local function fuelWithHose(vehicle)
	if fueling or plugged then return end

	-- kabel charger hanya untuk mobil listrik, selang bensin hanya untuk mobil bensin
	local electric = tank.isElectric(GetEntityModel(vehicle))

	if electric ~= (state.hoseElectric or false) then
		return lib.notify({ type = 'error', description = locale(electric and 'is_electric' or 'not_electric') })
	end

	if GetIsVehicleEngineRunning(vehicle) then
		return lib.notify({ type = 'error', description = locale('engine_off_first') })
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
	if not choice or not state.hose or plugged then return end

	local order = lib.callback.await('ox_fuel:start', false, netId, choice.type, choice.liters, choice.method)

	if not order or order.error then
		return lib.notify({ type = 'error', description = order and order.error or locale('vehicle_far') })
	end

	-- tancap corong di tutup tangki
	local cap = plug.world(vehicle, kind())
	TaskTurnPedToFaceCoord(cache.ped, cap.x, cap.y, cap.z, 600)
	Wait(600)
	handAnim()

	plugged = { vehicle = vehicle, netId = netId, pos = GetEntityCoords(vehicle) }
	fueling = { stop = false }
	CreateThread(publish)

	local offset = plug.get(vehicle, kind())
	local _, max = GetModelDimensions(GetEntityModel(vehicle))
	local at = GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, max.z + 0.6)

	local filled = 0.0
	local status, statusState = locale('holo_done'), 'done'
	local fillingText = locale(electric and 'holo_charging' or 'holo_filling')
	local lost = false

	local function push(text, stateName)
		display.update({
			title = order.title or (electric and 'CHARGER' or 'SPBU'),
			label = electric and 'DAYA' or 'BENSIN',
			unit = electric and 'kWh' or 'L',
			liters = filled,
			total = math.ceil(filled * order.price),
			percent = math.min(100, order.startPercent + filled / order.size * 100),
			status = text,
			state = stateName,
		})
	end

	display.show(at)
	push(fillingText)

	while not fueling.stop do
		Wait(config.refillTick)

		if fueling.stop then break end

		if plugLost() then
			lost = true
			status, statusState = locale('holo_stopped'), 'warn'
			break
		end

		if GetIsVehicleEngineRunning(vehicle) then
			lib.notify({ type = 'error', description = locale('engine_on_stop') })
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
	fueling = nil

	TriggerServerEvent('ox_fuel:finish', filled)

	if lost then ripOff() end
end

---Cabut corong dari kendaraan (berhenti mengisi bila masih mengisi), corong kembali ke tangan
local function unplug()
	if not plugged then return end

	if fueling then
		fueling.stop = true
		local timeout = GetGameTimer() + 2000
		while fueling and GetGameTimer() < timeout do Wait(0) end
	end

	if not plugged then return end -- lepas karena kendaraan bergerak

	local cap = plug.world(plugged.vehicle, kind())
	TaskTurnPedToFaceCoord(cache.ped, cap.x, cap.y, cap.z, 500)
	handAnim()
	plugged = nil
	publish()
end

---@return vector3? pump, boolean? electric, boolean? busy
local function getNearestPump(coords)
	for station in pairs(state.nearStations) do
		for i = 1, #station.pumps do
			local pump = station.pumps[i]
			if #(coords - pump) <= config.hose.pumpDistance then
				return pump, station.electric, station.electric and hose.takenByOther(pump)
			end
		end
	end
end

---@return string?, function?, function? teks prompt, aksi E, aksi G
local function getAction()
	marker = nil
	local coords = GetEntityCoords(cache.ped)
	local prefix = state.hoseElectric and 'charger_' or 'hose_'

	-- corong tertancap: player bebas (boleh pergi / duduk di mobil), cabut di dekat tutup tangki
	if plugged then
		if not fueling and plugLost() then return ripOff() end
		if cache.vehicle or IsEntityDead(cache.ped) or lib.progressActive() then return end

		local cap, distance = plug.world(plugged.vehicle, kind())
		if #(coords - cap) <= distance + 0.3 then
			return locale(prefix .. (fueling and 'stop' or 'unplug')), unplug
		end

		return
	end

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
		local doReturn = function() returnHose(false) end
		local vehicle = getNearbyVehicle(coords, 3.0)

		if vehicle then
			local cap, distance = plug.world(vehicle, kind())
			marker = cap

			-- harus di dekat tutup tangki
			if #(coords - cap) <= distance + 0.3 then
				local doFuel = function() fuelWithHose(vehicle) end
				-- mobil parkir mepet pompa: dekat keduanya -> E isi, G kembalikan selang
				if nearPump then return locale(prefix .. 'fuel_or_return'), doFuel, doReturn end
				return locale(prefix .. 'fuel'), doFuel
			end
		end

		if nearPump then return locale(prefix .. 'return'), doReturn end

		return
	end

	if cache.vehicle or state.isFueling or lib.progressActive() then return end

	local pump, electric, busy = getNearestPump(coords)

	if pump and electric then
		if busy then return locale('charger_busy') end
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
	description = 'SPBU: ambil/kembalikan selang, tancap/cabut corong',
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
		if plugged or state.hose or state.petrolCan or state.nearStation then
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

			local holding = state.hose and not plugged

			if holding then
				-- pegang corong: tidak bisa masuk kendaraan / pakai senjata
				DisableControlAction(0, 23, true)  -- masuk kendaraan
				DisableControlAction(0, 24, true)  -- tembak
				DisableControlAction(0, 25, true)  -- bidik
				DisableControlAction(0, 37, true)  -- weapon wheel
				DisablePlayerFiring(cache.playerId, true)

				-- titik tutup tangki kendaraan terdekat
				if marker then
					DrawMarker(28, marker.x, marker.y, marker.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.06, 0.06, 0.06, 56, 189, 248, 160, false, false, 2, false, nil, nil, false)
				end
			end

			Wait(holding and 0 or 200)
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
