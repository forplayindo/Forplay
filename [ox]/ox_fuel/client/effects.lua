-- Efek jenis BBM saat menyetir: konsumsi, knock (Pertalite di mobil performa), tenaga (Turbo di mobil performa)
local config = require 'config'
local tank = require 'shared.tank'
local effects = {}

local function effectOf(vehicle)
	local fuelType = Entity(vehicle).state.fuelType
	return fuelType and config.fuelEffects[fuelType], fuelType
end

---Pengali konsumsi BBM (SetFuelConsumptionRateMultiplier) untuk kendaraan ini
function effects.consumption(vehicle)
	local effect = effectOf(vehicle)
	return config.globalFuelConsumptionRate * (effect and effect.consumption or 1.0)
end

local function driving(vehicle, fuelType)
	return cache.vehicle == vehicle and cache.seat == -1 and DoesEntityExist(vehicle)
		and Entity(vehicle).state.fuelType == fuelType
end

---Dipanggil saat player mulai menyetir kendaraan berbahan bakar bensin
function effects.start(vehicle)
	local effect, fuelType = effectOf(vehicle)
	if not effect or not tank.isPerformance(GetEntityModel(vehicle)) then return end

	if effect.power then
		-- tenaga tambahan per frame; mesin rusak (< 500) diserahkan ke vehiclehandler
		CreateThread(function()
			while driving(vehicle, fuelType) do
				if GetIsVehicleEngineRunning(vehicle) and GetVehicleEngineHealth(vehicle) >= 500 then
					SetVehicleCheatPowerIncrease(vehicle, effect.power)
				end
				Wait(0)
			end
		end)
	end

	if effect.knock then
		-- mesin ngelitik: tiap interval detik menyetir, mesin & busi aus sedikit
		CreateThread(function()
			local seconds = 0
			local knock = config.knock

			while driving(vehicle, fuelType) do
				if GetIsVehicleEngineRunning(vehicle) and GetEntitySpeed(vehicle) > knock.minSpeed then
					seconds += 1

					if seconds >= knock.interval then
						seconds = 0
						SetVehicleEngineHealth(vehicle, math.max(0.0, GetVehicleEngineHealth(vehicle) - knock.engine))
						TriggerServerEvent('ox_fuel:knock', VehToNet(vehicle))
					end
				end
				Wait(1000)
			end
		end)
	end
end

return effects
