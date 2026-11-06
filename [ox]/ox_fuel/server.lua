local config = require 'config'

if not config then return end

if config.versionCheck then lib.versionCheck('overextended/ox_fuel') end

local ox_inventory = exports.ox_inventory

-- semua pompa untuk validasi jarak (player harus dalam jangkauan selang)
local pumps = {}

for _, list in pairs(lib.load('data.stations')) do
	for i = 1, #list do pumps[#pumps + 1] = list[i] end
end

local function isNearPump(coords)
	local maxDistance = config.hose.length + 1.5

	for i = 1, #pumps do
		if #(coords - pumps[i]) <= maxDistance then return true end
	end

	return false
end

---@param vehicle number
---@param fuel number
---@param reduceOnly? boolean Don't allow fuel to be increased, unless fuel state has not been initialised.
local function setFuelState(vehicle, fuel, reduceOnly)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then
		return
	end

	local state = Entity(vehicle).state
	fuel = math.clamp(fuel, 0, reduceOnly and state.fuel or 100)

	state:set('fuel', fuel, true)
end

---@param playerId number
---@param price number
---@return boolean?
local function defaultPaymentMethod(playerId, price)
	local success = ox_inventory:RemoveItem(playerId, 'money', price)

	if success then return true end

	local money = ox_inventory:GetItemCount(playerId, 'money')

	TriggerClientEvent('ox_lib:notify', playerId, {
		type = 'error',
		description = locale('not_enough_money', price - money)
	})
end

local payMoney = defaultPaymentMethod

exports('setPaymentMethod', function(fn)
	payMoney = fn or defaultPaymentMethod
end)

RegisterNetEvent('ox_fuel:pay', function(_, fuel, netid)
	local source = source
	if type(fuel) ~= 'number' or type(netid) ~= 'number' then return end

	-- harga dihitung server dari selisih bensin, bukan dari angka kiriman client
	local vehicle = NetworkGetEntityFromNetworkId(netid)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return end
	local playerCoords = GetEntityCoords(GetPlayerPed(source))
	if #(playerCoords - GetEntityCoords(vehicle)) > 8.0 or not isNearPump(playerCoords) then return end

	local current = Entity(vehicle).state.fuel or 0
	fuel = math.clamp(fuel, 0, 100)
	if fuel - current <= 0 then return end

	-- isi sebanyak yang mampu dibayar (uang pas-pasan tidak membuat seluruh pengisian gagal)
	local ticks = math.ceil((fuel - current) / config.refillValue - 0.001)
	ticks = math.min(ticks, math.floor(ox_inventory:GetItemCount(source, 'money') / config.priceTick))

	if ticks <= 0 then
		return TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = locale('refuel_cannot_afford') })
	end

	fuel = math.min(current + ticks * config.refillValue, fuel)
	local price = ticks * config.priceTick
	if not payMoney(source, price) then return end

	setFuelState(vehicle, fuel)

	TriggerClientEvent('ox_lib:notify', source, {
		type = 'success',
		description = locale('fuel_success', ('%d%%'):format(math.floor(fuel)), math.groupdigits(price, '.'))
	})
end)

-- selang ditarik terlalu jauh -> pompa meledak (divalidasi + cooldown)
local pumpCooldown, playerCooldown = {}, {}

RegisterNetEvent('ox_fuel:hoseSnapped', function(pump)
	local source = source
	if not config.hose.explode or type(pump) ~= 'vector3' then return end

	local now = os.time()
	if (playerCooldown[source] or 0) > now then return end

	local target
	for i = 1, #pumps do
		if #(pumps[i] - pump) < 0.5 then target = pumps[i] break end
	end

	if not target then return end

	-- harus benar-benar jauh dari pompa (bukan sedang mengembalikan selang)
	local distance = #(GetEntityCoords(GetPlayerPed(source)) - target)
	if distance < config.hose.length - 2.0 or distance > config.hose.length + 6.0 then
		return lib.print.warn(('hoseSnapped ditolak: player %s jarak %.2f m dari pompa'):format(source, distance))
	end

	local key = ('%.1f:%.1f'):format(target.x, target.y)
	if (pumpCooldown[key] or 0) > now then return end

	pumpCooldown[key] = now + config.hose.explodeCooldown
	playerCooldown[source] = now + config.hose.explodeCooldown
	TriggerClientEvent('ox_fuel:explodePump', source, target)
end)

AddEventHandler('playerDropped', function()
	playerCooldown[source] = nil
end)

RegisterNetEvent('ox_fuel:fuelCan', function(hasCan)
	local source = source
	if not config.petrolCan.enabled then return end
	local price = hasCan and config.petrolCan.refillPrice or config.petrolCan.price
	if hasCan then
		local item = ox_inventory:GetCurrentWeapon(source)

		if not item or item.name ~= 'WEAPON_PETROLCAN' or not payMoney(source, price) then return end

		item.metadata.durability = 100
		item.metadata.ammo = 100

		ox_inventory:SetMetadata(source, item.slot, item.metadata)

		TriggerClientEvent('ox_lib:notify', source, {
			type = 'success',
			description = locale('petrolcan_refill', price)
		})
	else
		if not ox_inventory:CanCarryItem(source, 'WEAPON_PETROLCAN', 1) then
			return TriggerClientEvent('ox_lib:notify', source, {
				type = 'error',
				description = locale('petrolcan_cannot_carry')
			})
		end

		if not payMoney(source, price) then return end

		ox_inventory:AddItem(source, 'WEAPON_PETROLCAN', 1)

		TriggerClientEvent('ox_lib:notify', source, {
			type = 'success',
			description = locale('petrolcan_buy', price)
		})
	end
end)

RegisterNetEvent('ox_fuel:updateFuelCan', function(durability, netid, fuel)
	local source = source
	if type(durability) ~= 'number' or type(netid) ~= 'number' or type(fuel) ~= 'number' or durability <= 0 then return end

	local item = ox_inventory:GetCurrentWeapon(source)
	if not item or item.name ~= 'WEAPON_PETROLCAN' then return end

	local vehicle = NetworkGetEntityFromNetworkId(netid)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return end
	if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(vehicle)) > 5.0 then return end

	-- tambahan bensin dibatasi isi jerigen yang benar-benar terpakai
	durability = math.min(durability, item.metadata.ammo or 0)
	if durability <= 0 then return end

	local current = Entity(vehicle).state.fuel or 0
	fuel = math.min(fuel, current + durability / config.durabilityTick * config.refillValue, 100)
	if fuel <= current then return end

	local left = math.floor(item.metadata.durability - durability)
	item.metadata.durability = left
	item.metadata.ammo = left

	ox_inventory:SetMetadata(source, item.slot, item.metadata)
	setFuelState(vehicle, fuel)
end)

RegisterNetEvent('ox_fuel:setFuel', function(fuel)
	local playerPed = GetPlayerPed(source)
	local handle = GetVehiclePedIsIn(playerPed, false)

	setFuelState(handle, fuel, true)
end)
-- ============================================================================
-- Pompa: menu jenis BBM + liter + Cash/Transfer. Bayar saat selesai, sesuai liter yang masuk.
-- ============================================================================
local tank = require 'shared.tank'
local orders = {} -- [source] = { vehicle, type, liters, method, size, startedAt }

local function trim(text)
	return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- posisi charger sama dengan yang di-spawn client (data/chargers.lua)
local chargers = lib.load('data.chargers')

local function isNearCharger(coords)
	if not config.electric.enabled then return false end

	for i = 1, #chargers do
		if #(coords - chargers[i].xyz) <= config.hose.length + 2.0 then return true end
	end

	return false
end

---Player di stasiun yang cocok: mobil listrik di charger, mobil bensin di pompa
local function atStation(coords, electric)
	if electric then return isNearCharger(coords) end
	return isNearPump(coords)
end

---Kendaraan valid untuk diisi oleh player ini
---@return number? vehicle, boolean? electric
local function pumpVehicle(source, netid)
	if type(netid) ~= 'number' then return end

	local vehicle = NetworkGetEntityFromNetworkId(netid)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return end

	local coords = GetEntityCoords(GetPlayerPed(source))
	if #(coords - GetEntityCoords(vehicle)) > 8.0 then return end

	local electric = tank.isElectric(GetEntityModel(vehicle))
	if not atStation(coords, electric) then return end

	return vehicle, electric
end

---12.5 -> '12,5', 12.0 -> '12'
local function formatLiters(liters)
	local text = ('%.1f'):format(liters):gsub('%.0$', ''):gsub('%.', ',')
	return text
end

local function litersIn(vehicle, size)
	return size * (Entity(vehicle).state.fuel or 0) / 100
end

lib.callback.register('ox_fuel:quote', function(source, netid)
	local vehicle, electric = pumpVehicle(source, netid)
	local player = vehicle and exports.qbx_core:GetPlayer(source)
	if not player then return end

	local model = GetEntityModel(vehicle)
	local size = tank.size(model)
	local current = litersIn(vehicle, size)
	local data = exports.qbx_core:GetVehiclesByHash(model)

	-- tombol mode charger: tampilkan lama isi penuh di bawah nama (menu menghitung perkiraan detik dari rate)
	local types = config.fuelTypes
	if electric then
		types = {}
		for i = 1, #tank.electricModes do
			local mode = tank.electricModes[i]
			types[i] = {
				id = mode.id, label = mode.label, price = mode.price, color = mode.color,
				rate = size / mode.fullTime, sub = ('Penuh ±%s mnt'):format(formatLiters(mode.fullTime / 60)),
			}
		end
	end

	return {
		label = ('%s · %s'):format(data and data.name or 'Kendaraan', trim(GetVehicleNumberPlateText(vehicle))),
		tank = size,
		current = current,
		free = size - current,
		electric = electric,
		unit = electric and 'kWh' or 'L',
		types = types,
		lastType = not electric and Entity(vehicle).state.fuelType or nil,
		cash = player.PlayerData.money.cash or 0,
		bank = player.PlayerData.money.bank or 0,
	}
end)

lib.callback.register('ox_fuel:start', function(source, netid, typeId, liters, method)
	if (method ~= 'cash' and method ~= 'bank') or type(liters) ~= 'number' then return end

	local vehicle, electric = pumpVehicle(source, netid)
	local player = vehicle and exports.qbx_core:GetPlayer(source)
	if not player then return end

	local fuelType
	if electric then
		fuelType = tank.electricMode(typeId)
	else
		fuelType = tank.fuelType(typeId)
	end
	if not fuelType then return end

	local size = tank.size(GetEntityModel(vehicle))
	liters = math.min(math.floor(liters), math.floor(size - litersIn(vehicle, size)))

	if liters < 1 then return { error = locale('tank_full') } end

	if math.ceil(liters * fuelType.price) > (player.PlayerData.money[method] or 0) then
		return { error = locale(method == 'cash' and 'refuel_cannot_afford' or 'bank_not_enough') }
	end

	-- kecepatan isi per refillTick: charger = baterai penuh dalam fullTime detik (fast lebih cepat), bensin selalu sama
	local rate = electric and size * config.refillTick / (fuelType.fullTime * 1000) or config.litersPerTick

	orders[source] = {
		vehicle = vehicle, type = fuelType, liters = liters, method = method, size = size, rate = rate,
		electric = electric, startedAt = GetGameTimer(), position = GetEntityCoords(vehicle),
	}

	return {
		liters = liters, size = size, rate = rate, startPercent = Entity(vehicle).state.fuel or 0, price = fuelType.price,
		title = electric and (fuelType.holo or 'CHARGER') or 'SPBU',
	}
end)

---@param claimed number liter menurut client (dibatasi pesanan & waktu yang berlalu)
local function finishOrder(source, claimed)
	local order = orders[source]
	if not order then return end
	orders[source] = nil

	local vehicle = order.vehicle
	if not DoesEntityExist(vehicle) then return end

	local maxByTime = ((GetGameTimer() - order.startedAt) / config.refillTick + 2) * order.rate
	local filled = math.min(tonumber(claimed) or 0, order.liters, maxByTime)

	local player = exports.qbx_core:GetPlayer(source)
	if not player then return end

	-- uang dipindah di tengah pengisian: isi sebanyak yang masih terbayar
	filled = math.min(filled, (player.PlayerData.money[order.method] or 0) / order.type.price)
	filled = math.floor(filled * 10) / 10
	if filled <= 0 then return end

	local price = math.ceil(filled * order.type.price)

	if not player.Functions.RemoveMoney(order.method, price, 'bensin') then
		return TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = locale('refuel_cannot_afford') })
	end

	local state = Entity(vehicle).state
	local before = litersIn(vehicle, order.size)

	setFuelState(vehicle, (state.fuel or 0) + filled / order.size * 100)

	-- jenis BBM di tangki mengikuti yang paling banyak
	if not order.electric and filled >= before then state:set('fuelType', order.type.id, true) end

	TriggerClientEvent('ox_lib:notify', source, {
		type = 'success',
		description = locale(order.electric and 'charge_success' or 'pump_success', formatLiters(filled),
			order.type.label, math.groupdigits(price, '.')),
	})
end

RegisterNetEvent('ox_fuel:finish', function(claimed)
	local source = source
	local order = orders[source]
	if not order then return end

	-- corong ditancap lalu ditinggal: player boleh di mana saja, yang dicek kendaraannya masih di tempat mengisi
	-- (client berhenti begitu kendaraan bergeser 0,5 m; jumlah tetap dibatasi pesanan & waktu di finishOrder)
	if not DoesEntityExist(order.vehicle) or #(GetEntityCoords(order.vehicle) - order.position) > 25.0 then
		orders[source] = nil
		return
	end

	finishOrder(source, claimed)
end)

-- keluar game di tengah pengisian: selesaikan sesuai waktu yang sudah berjalan
AddEventHandler('playerDropped', function()
	finishOrder(source, math.huge)
end)

-- ============================================================================
-- Knock: Pertalite di mobil performa -> busi aus (sistem kondisi f_mechanicjob)
-- ============================================================================
local lastKnock = {}

RegisterNetEvent('ox_fuel:knock', function(netid)
	local source = source
	local vehicle = NetworkGetEntityFromNetworkId(tonumber(netid) or 0)
	if vehicle == 0 or not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(source) then return end

	local fuelType = Entity(vehicle).state.fuelType
	local effect = fuelType and config.fuelEffects[fuelType]
	if not effect or not effect.knock or not tank.isPerformance(GetEntityModel(vehicle)) then return end

	-- maksimal sekali per interval (toleransi 20%)
	local now = os.time()
	if (lastKnock[source] or 0) > now then return end
	lastKnock[source] = now + math.floor(config.knock.interval * 0.8)

	if GetResourceState('f_mechanicjob') ~= 'started' then return end

	pcall(function()
		exports.f_mechanicjob:AddWear(vehicle, 'sparkplugs', config.knock.sparkplugs)
	end)
end)

AddEventHandler('playerDropped', function()
	lastKnock[source] = nil
end)
