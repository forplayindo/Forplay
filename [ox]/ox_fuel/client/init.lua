local config = require 'config'

if not config then return end

SetFuelConsumptionState(true)
SetFuelConsumptionRateMultiplier(config.globalFuelConsumptionRate)

AddTextEntry('ox_fuel_station', locale('fuel_station_blip'))

local utils = require 'client.utils'
local state = require 'client.state'
local fuel  = require 'client.fuel'
local tank  = require 'shared.tank'
local effects = require 'client.effects'

require 'client.stations'
require 'client.chargers'

---Baterai kendaraan listrik: berkurang menurut RPM (seperti caticus KwUsage), bukan konsumsi native
local function electricDrain(vehicle, level)
	local rpm = math.floor(GetVehicleCurrentRpm(vehicle) * 10 + 0.5) / 10
	local usage = config.electric.usage[rpm] or 0.0
	return level - usage * config.electric.usageMultiplier / 10
end

local function startDrivingVehicle()
	local vehicle = cache.vehicle
	local electric = tank.isElectric(GetEntityModel(vehicle))

	if not electric and not DoesVehicleUseFuel(vehicle) then return end

	local vehState = Entity(vehicle).state

	if not vehState.fuel then
		local level = GetVehicleFuelLevel(vehicle)
		-- mobil listrik sering tidak punya tangki native (level 0) -> anggap baterai penuh
		if electric and level <= 0 then level = 100.0 end
		TriggerServerEvent('ox_fuel:setFuel', level)
		while not vehState.fuel do Wait(0) end
	end

	SetVehicleFuelLevel(vehicle, vehState.fuel)

	if not electric then effects.start(vehicle) end

	local fuelTick = 0

	while cache.seat == -1 do
		if GetIsVehicleEngineRunning(vehicle) then
			if not DoesEntityExist(vehicle) then return end
			-- listrik: konsumsi native dimatikan, baterai dihitung sendiri; bensin: pengali sesuai jenis BBM
			SetFuelConsumptionRateMultiplier(electric and 0.0 or effects.consumption(vehicle))

			local fuelAmount = tonumber(vehState.fuel)
			local newFuel = electric and electricDrain(vehicle, fuelAmount) or GetVehicleFuelLevel(vehicle)

			-- baterai habis: mesin mati
			if electric and newFuel <= 0 then SetVehicleEngineOn(vehicle, false, true, true) end

			if fuelAmount > 0 then
				if not electric and GetVehiclePetrolTankHealth(vehicle) < 700 then
					newFuel -= math.random(10, 20) * 0.01
				end

				if fuelAmount ~= newFuel then
					if fuelTick == 15 then
						fuelTick = 0
					end

					fuel.setFuel(vehState, vehicle, newFuel, fuelTick == 0)
					fuelTick += 1
				end
			end
		else
			if not DoesEntityExist(vehicle) then return end
			SetFuelConsumptionRateMultiplier(0.0)
		end
		Wait(1000)
	end

	fuel.setFuel(vehState, vehicle, vehState.fuel, true)
end

if cache.seat == -1 then CreateThread(startDrivingVehicle) end

lib.onCache('seat', function(seat)
	if cache.vehicle then
		state.lastVehicle = cache.vehicle
	end

	if seat == -1 then
		SetTimeout(0, startDrivingVehicle)
	end
end)

if config.ox_target then return require 'client.target' end

require 'client.interact'
