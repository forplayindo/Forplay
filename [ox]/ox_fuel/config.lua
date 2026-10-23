if not lib.checkDependency('ox_lib', '3.22.0', true) then return end
if not lib.checkDependency('ox_inventory', '2.30.0', true) then return end

return {
	-- Get notified when a new version releases
	versionCheck = true,

	-- Enable support for ox_target
	ox_target = false,

	/*
	* Show or hide gas stations blips
	* 0 - Hide all
	* 1 - Show nearest (5000ms interval check)
	* 2 - Show all
	*/
	showBlips = 0, -- blip SPBU dipindah ke f_blips

	-- Total duration (ex. 10% missing fuel): 10 / 0.25 * 250 = 10 seconds

	-- Fuel refill value (every 250msec add 0.25%)
	refillValue = 0.50,

	-- Fuel tick time (every 250 msec)
	refillTick = 250,

	-- Fuel cost (Added once every tick)
	priceTick = 1000, -- Rp per tick (0,5%): tangki kosong -> penuh +-Rp 200.000

	-- Can durability loss per refillTick
	durabilityTick = 1.3,

	-- Enables fuel can
	petrolCan = {
		enabled = true,
		duration = 5000,
		price = 100000,
		refillPrice = 70000,
	},

	-- Jenis BBM di pompa (harga per liter). Pembeda tiap jenis (konsumsi/aus/turbo) menyusul.
	fuelTypes = {
		{ id = 'pertalite', label = 'Pertalite', ron = 90, price = 3000, color = '#22c55e' },
		{ id = 'pertamax', label = 'Pertamax', ron = 92, price = 3800, color = '#3b82f6' },
		{ id = 'turbo', label = 'Pertamax Turbo', ron = 98, price = 4400, color = '#ef4444' },
	},

	-- Pembeda jenis BBM (jenis di tangki = yang paling banyak diisi, state kendaraan 'fuelType')
	--  consumption = pengali konsumsi BBM (0.9 = 10% lebih irit)
	--  knock       = mesin "ngelitik" di mobil performa -> busi & mesin pelan-pelan aus
	--  power       = tenaga mesin di mobil performa (1.06 = +6%)
	fuelEffects = {
		pertalite = { consumption = 1.0, knock = true },
		pertamax = { consumption = 0.9 },
		turbo = { consumption = 0.85, power = 1.06 },
	},
	-- kategori qbx yang dianggap mobil performa (kena knock / dapat tenaga turbo)
	performanceCategories = { sports = true, super = true },
	-- knock: tiap `interval` detik menyetir (mesin hidup, > minSpeed m/s) -> busi -sparkplugs %, mesin -engine (dari 1000)
	knock = { interval = 60, minSpeed = 5.0, sparkplugs = 1.0, engine = 4.0 },

	-- Kecepatan isi selang: liter per refillTick (0.5 L / 250 ms = 2 L/detik)
	litersPerTick = 0.5,

	-- Kendaraan listrik (adaptasi caticus-fuelsystem): isi daya di stasiun charger, bukan pompa bensin
	electric = {
		enabled = true,
		price = 2000,       -- Rp per kWh (75 kWh penuh = Rp 150.000, sedikit lebih murah dari bensin)
		kwhPerTick = 0.5,   -- 0.5 kWh / 250 ms = 2 kWh/detik
		batteryDefault = 75, -- kWh
		batteryModels = {},  -- per model: ['neon'] = 80,
		-- model listrik (nama spawn). Mobil listrik addon: tambahkan di sini.
		models = {
			cyclone = true, cyclone2 = true, dilettante = true, dilettante2 = true, iwagen = true, imorgon = true,
			khamelion = true, neon = true, omnisegt = true, raiden = true, surge = true, tezeract = true,
			virtue = true, voltic = true, buffalo5 = true,
		},
		-- pemakaian baterai per detik menurut RPM (persen / 10), dari caticus Config.KwUsage
		usage = { [1.0] = 1.4, [0.9] = 1.2, [0.8] = 1.0, [0.7] = 0.9, [0.6] = 0.8, [0.5] = 0.7, [0.4] = 0.5, [0.3] = 0.4, [0.2] = 0.001, [0.1] = 0.001, [0.0] = 0.0 },
		usageMultiplier = 1.0,
		-- model charger bawaan GTA di titik supercharger (hash dari caticus)
		chargerModels = { 1467552538 },
		stationRadius = 30.0, -- charger dicari dalam radius ini dari titik stasiun
		-- titik stasiun charger (caticus Config.SuperchargerStations)
		stations = {
			vec3(153.4138, 6592.721, 30.8449),
			vec3(2697.205, 3277.662, 54.24057),
			vec3(-2534.736, 2345.22, 32.05991),
			vec3(645.1025, 280.3252, 102.1716),
			vec3(-729.0958, -911.1166, 18.01393),
		},
	},

	-- tinggi ujung selang per model pompa (dari caticus); model lain pakai hose.anchorHeight
	pumpAnchor = {
		[`prop_gas_pump_1a`] = 2.3, [`prop_gas_pump_1b`] = 2.3, [`prop_gas_pump_1c`] = 2.3, [`prop_gas_pump_1d`] = 2.3,
		[`prop_vintage_pump`] = 1.8, [`prop_gas_pump_old2`] = 1.6, [`prop_gas_pump_old3`] = 1.6,
		[1467552538] = 1.6,
	},

	-- Ukuran tangki (liter) per kategori kendaraan (qbx_core shared/vehicles.lua)
	tankDefault = 60.0,
	tankSizes = {
		compacts = 40, sedans = 55, coupes = 55, sports = 60, sportsclassics = 60, super = 70,
		muscle = 65, suvs = 75, offroad = 70, vans = 80, utility = 120, service = 100,
		emergency = 80, commercial = 200, industrial = 200, military = 200, motorcycles = 12,
		openwheel = 60, boats = 100, helicopters = 300, planes = 400,
	},
	-- per model, mengalahkan kategori: ['bus'] = 250,
	tankModels = {},

	-- Selang pompa: ambil corong di pompa -> isi di tutup tangki -> kembalikan
	hose = {
		length = 15.0,       -- lebih jauh dari ini selang lepas & corong kembali ke pompa
		pumpDistance = 1.8,  -- jarak player ke pompa untuk ambil/kembalikan
		capDistance = 1.5,   -- jarak player ke body mobil untuk muncul [E] Isi bensin
		anchorHeight = 2.1,  -- tinggi ujung selang di pompa
		warnDistance = 13.0, -- notifikasi "selang hampir putus"
		explode = true,      -- selang putus = pompa meledak (player/mobil dekat ikut kena)
		explodeCooldown = 60, -- detik per pompa (anti spam)
		-- animasi saat mengisi (sama dengan beli/isi jerigen); flag 49 = tubuh atas saja, loop
		-- freeze = pose dibekukan di `frame` (0.0-1.0) supaya tangan tidak bergerak
		anim = { dict = 'timetable@gardener@filling_can', clip = 'gar_ig_5_filling_can', flag = 49, frame = 0.0, freeze = false },
	},

	---Modifies the fuel consumption rate of all vehicles - see [`SET_FUEL_CONSUMPTION_RATE_MULTIPLIER`](https://docs.fivem.net/natives/?_0x845F3E5C).
	globalFuelConsumptionRate = 10.0,

	-- Gas pump models
	pumpModels = {
		`prop_gas_pump_old2`,
		`prop_gas_pump_1a`,
		`prop_vintage_pump`,
		`prop_gas_pump_old3`,
		`prop_gas_pump_1c`,
		`prop_gas_pump_1b`,
		`prop_gas_pump_1d`,
	}
}
