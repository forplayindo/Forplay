--- Contains code relevant to the physical hospital building. Things like checking in, beds, spawning vehicles, etc.

---@class Player object from core

local config = require 'config.server'
local sharedConfig = require 'config.shared'
local triggerEventHooks = require '@qbx_core.modules.hooks'
local doctorCalled = false

---@type table<string, table<number, boolean>>
local hospitalBedsTaken = {}

for hospitalName, hospital in pairs(sharedConfig.locations.hospitals) do
	hospitalBedsTaken[hospitalName] = {}
	for i = 1, #hospital.beds do
		hospitalBedsTaken[hospitalName][i] = false
	end
end

local function getOpenBed(hospitalName)
	local beds = hospitalBedsTaken[hospitalName]
	for i = 1, #beds do
		local isTaken = beds[i]
		if not isTaken then return i end
	end
end

lib.callback.register('f_ambulancejob:server:getOpenBed', function(_, hospitalName)
	return getOpenBed(hospitalName)
end)

local function formatMoney(n)
	local s = tostring(math.floor(n))
	local k
	repeat s, k = s:gsub('^(%d+)(%d%d%d)', '%1,%2') until k == 0
	return s
end

---Email tagihan lewat f_phone Mail; fallback notifikasi phone kalau belum punya akun mail
local function sendBillMail(src, player, hospitalLabel, amount)
	local ci = player.PlayerData.charinfo or {}
	local name = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
	local lines = {}
	for i, line in ipairs(config.billMail.body) do lines[i] = line end
	lines[1] = lines[1]:format(name)
	lines[3] = lines[3]:format(hospitalLabel)
	lines[4] = lines[4]:format(formatMoney(amount))
	lines[7] = lines[7]:format(hospitalLabel)
	local subject = config.billMail.subject

	local okA, addresses = pcall(function() return exports['f_phone']:getMailAddresses(player.PlayerData.citizenid) end)
	if okA and type(addresses) == 'table' and #addresses > 0 then
		local to = {}
		for i = 1, #addresses do to[i] = addresses[i].email end
		local okS, res = pcall(function()
			return exports['f_phone']:sendMail({ to = to, subject = subject, body = table.concat(lines, '\n'), from = { name = hospitalLabel, email = '' } })
		end)
		if okS and res and (res.delivered or 0) > 0 then return end
	end

	pcall(function()
		exports['f_phone']:notify(src, { appId = 'mail', app = 'Mail', title = subject, body = lines[4], time = 'now' })
	end)
end

-- Pasien yang dirawat (check-in / dibawa ke RS saat waktu habis) baru dipotong biayanya saat
-- bangun dari kasur (tekan E). Disimpan di server supaya client tidak bisa melewatinya.
---@type table<number, { hospital: string, bed: number }>
local pendingBill = {}

---@param src number
local function billPlayer(src)
	local bill = pendingBill[src]
	if not bill then return end
	pendingBill[src] = nil

	local player = exports.qbx_core:GetPlayer(src)
	if not player then return end

	local cost = sharedConfig.checkInCost
	player.Functions.RemoveMoney('bank', cost, 'hospital-administration')
	config.depositSociety('ambulance', cost)

	local hospital = sharedConfig.locations.hospitals[bill.hospital]
	local label = hospital and hospital.label or bill.hospital
	sendBillMail(src, player, label, cost)
	exports.qbx_core:Notify(src, locale('info.bill_paid', formatMoney(cost), label), 'inform', 7000)
end

RegisterNetEvent('f_ambulancejob:server:playerEnteredBed', function(hospitalName, bedIndex)
	if GetInvokingResource() then return end
	local src = source
	if not hospitalBedsTaken[hospitalName] or hospitalBedsTaken[hospitalName][bedIndex] == nil then return end
	pendingBill[src] = { hospital = hospitalName, bed = bedIndex }
	hospitalBedsTaken[hospitalName][bedIndex] = true
end)

RegisterNetEvent('f_ambulancejob:server:playerLeftBed', function(hospitalName, bedIndex)
	if GetInvokingResource() then return end
	local src = source
	if hospitalBedsTaken[hospitalName] then hospitalBedsTaken[hospitalName][bedIndex] = false end
	billPlayer(src)
end)

-- keluar game saat masih di kasur tetap ditagih
AddEventHandler('playerDropped', function()
	local src = source
	local bill = pendingBill[src]
	if not bill then return end
	if hospitalBedsTaken[bill.hospital] then hospitalBedsTaken[bill.hospital][bill.bed] = false end
	billPlayer(src)
	pendingBill[src] = nil
end)

-- Sebelumnya tanpa cek apa pun: siapa saja bisa memindahkan player mana pun ke kasur dari mana saja.
-- Sekarang: EMS on duty, EMS dekat kasur itu, pasien dekat EMS.
---@param playerId number
RegisterNetEvent('hospital:server:putPlayerInBed', function(playerId, hospitalName, bedIndex)
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	local job = player and player.PlayerData.job
	if not job or job.type ~= 'ems' or not job.onduty then return end

	playerId = tonumber(playerId)
	local hospital = sharedConfig.locations.hospitals[hospitalName]
	local bed = hospital and hospital.beds[tonumber(bedIndex) or 0]
	if not playerId or playerId == src or not bed or not exports.qbx_core:GetPlayer(playerId) then return end

	local emsCoords = GetEntityCoords(GetPlayerPed(src))
	if #(emsCoords - bed.coords.xyz) > 5.0 then return end
	if #(emsCoords - GetEntityCoords(GetPlayerPed(playerId))) > 3.0 then return end

	TriggerClientEvent('f_ambulancejob:client:putPlayerInBed', playerId, hospitalName, bedIndex)
end)

lib.callback.register('f_ambulancejob:server:isBedTaken', function(_, hospitalName, bedIndex)
	return hospitalBedsTaken[hospitalName][bedIndex]
end)

---@param src number
local function wipeInventory(src)
	exports.ox_inventory:ClearInventory(src)
	exports.qbx_core:Notify(src, locale('error.possessions_taken'), 'error')
end

lib.callback.register('f_ambulancejob:server:spawnVehicle', function(source, vehicleName, vehicleCoords)
	local netId, veh = qbx.spawnVehicle({ spawnSource = vehicleCoords or source, model = vehicleName, warp = GetPlayerPed(source)})

	local vehType = GetVehicleType(veh)
	local platePrefix = (vehType == 'heli') and locale('info.heli_plate') or locale('info.amb_plate')
	local plate = platePrefix .. tostring(math.random(1000, 9999))

	SetVehicleNumberPlateText(veh, plate)
	TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
	return netId
end)

local function sendDoctorAlert()
	if doctorCalled then return end
	doctorCalled = true
	local _, doctors = exports.qbx_core:GetDutyCountType('ems')
	for i = 1, #doctors do
		local doctor = doctors[i]
		exports.qbx_core:Notify(doctor, locale('info.dr_needed'), 'inform')
	end

	SetTimeout(config.doctorCallCooldown * 60000, function()
		doctorCalled = false
	end)
end

local function canCheckIn(source, hospitalName)
	local numDoctors = exports.qbx_core:GetDutyCountType('ems')
	if numDoctors >= sharedConfig.minForCheckIn then
		exports.qbx_core:Notify(source, locale('info.dr_alert'), 'inform')
		sendDoctorAlert()
		return false
	end

	if not triggerEventHooks('checkIn', { source = source, hospitalName = hospitalName }) then return false end

	return true
end

lib.callback.register('f_ambulancejob:server:canCheckIn', canCheckIn)

---Sends the patient to an open bed within the hospital
---@param src number the player doing the checking in
---@param patientSrc number the player being checked in
---@param hospitalName string name of the hospital matching the config where player should be placed
local function checkIn(src, patientSrc, hospitalName)
	if src == patientSrc and not canCheckIn(patientSrc, hospitalName) then return false end

	local bedIndex = getOpenBed(hospitalName)
	if not bedIndex then
		exports.qbx_core:Notify(src, locale('error.beds_taken'), 'error')
		return false
	end

	TriggerClientEvent('f_ambulancejob:client:checkedIn', patientSrc, hospitalName, bedIndex)
	return true
end

lib.callback.register('f_ambulancejob:server:checkIn', checkIn)

exports('CheckIn', checkIn)

local function respawn(src)
	local player = exports.qbx_core:GetPlayer(src)
	local closestHospital
	if player.PlayerData.metadata.injail > 0 then
		closestHospital = 'jail'
	else
		local coords = GetEntityCoords(GetPlayerPed(src))
		local closest = nil

		for hospitalName, hospital in pairs(sharedConfig.locations.hospitals) do
			if hospitalName ~= 'jail' then
				if not closest or #(coords - hospital.coords) < #(coords - closest) then
					closest = hospital.coords
					closestHospital = hospitalName
				end
			end
		end
	end

	local bedIndex = getOpenBed(closestHospital)
	if not bedIndex then
		exports.qbx_core:Notify(src, locale('error.beds_taken'), 'error')
		return
	end
	TriggerClientEvent('f_ambulancejob:client:checkedIn', src, closestHospital, bedIndex)

	if config.wipeInvOnRespawn then
		wipeInventory(src)
	end
end

AddEventHandler('f_medical:server:playerRespawned', respawn)
