local sharedConfig = require 'config.shared'

---@alias source number

local function alertAmbulance(src, text)
	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	local players = exports.qbx_core:GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.type == 'ems' and v.PlayerData.job.onduty then
			TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, text)
		end
	end
end

local function registerArmory()
	for _, armory in pairs(sharedConfig.locations.armory) do
		exports.ox_inventory:RegisterShop(armory.shopType, armory)
	end
end

local function registerStashes()
    for _, stash in pairs(sharedConfig.locations.stash) do
        exports.ox_inventory:RegisterStash(stash.name, stash.label, stash.slots, stash.weight, stash.owner, stash.groups, stash.location)
    end
end

RegisterNetEvent('hospital:server:ambulanceAlert', function(text)
	if GetInvokingResource() then return end
	local src = source
	alertAmbulance(src, text or locale('info.civ_down'))
end)

RegisterNetEvent('hospital:server:emergencyAlert', function()
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	alertAmbulance(src, locale('info.ems_down', player.PlayerData.charinfo.lastname))
end)

-- Alert otomatis saat player tergeletak dimatikan: player memanggil EMS sendiri lewat tombol di
-- f_deathscreen (notifikasi f_phone + blip), supaya EMS tidak kebanjiran alert dobel.

-- Cek status / obati / revive pasien sekarang lewat panel "Cek Pasien" (server/patient.lua).
-- Event lama hospital:server:TreatWounds / RevivePlayer / UseFirstAid dihapus: tanpa cek jarak
-- dan warga bisa memakai P3K ke orang lain (sekarang khusus EMS).

lib.callback.register('f_ambulancejob:server:getNumDoctors', function()
	return exports.qbx_core:GetDutyCountType('ems')
end)

lib.addCommand('911e', {
    help = locale('info.ems_report'),
    params = {
        {name = 'message', help = locale('info.message_sent'), type = 'longString', optional = true},
    }
}, function(source, args)
	local message = args.message or locale('info.civ_call')
	local ped = GetPlayerPed(source)
	local coords = GetEntityCoords(ped)
	local players = exports.qbx_core:GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.type == 'ems' and v.PlayerData.job.onduty then
			TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, message)
		end
	end
end)

-- /status, /heal, /revivep dihapus: diganti panel "Cek Pasien" (ox_target, khusus EMS on duty).
-- Perban & Painkiller dipakai sendiri lewat ox_inventory (client export di client/wounding.lua),
-- item EMS lain hanya dipakai lewat panel.


AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    registerArmory()
    registerStashes()
end)