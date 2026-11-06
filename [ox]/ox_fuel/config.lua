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
		-- Mode pengisian daya, dipilih di menu charger (urutan = urutan tombol, yang pertama jadi default)
		--  price    = Rp per kWh
		--  fullTime = detik untuk 0 -> 100%, sama untuk semua ukuran baterai (isi sebagian = proporsional)
		--  holo     = judul hologram saat mengisi
		modes = {
			-- 75 kWh penuh: Rp 150.000, 2 menit
			{ id = 'normal', label = 'Normal', price = 2000, fullTime = 120, color = '#facc15', holo = 'CHARGER' },
			-- 75 kWh penuh: Rp 225.000, 1 menit (2x lebih cepat, 50% lebih mahal)
			{ id = 'fast', label = 'Fast Charging', price = 3000, fullTime = 60, color = '#f97316', holo = 'FAST CHARGER' },
		},
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
		-- Prop charger (f_addonprop stream/ev_charger). Posisi di data/chargers.lua, di-spawn lokal oleh client/chargers.lua.
		-- full = pistol tergantung di holster, empty = pistol sedang dipakai (model ditukar otomatis)
		chargerModel = { full = `4play_ev_charge_station`, empty = `4play_ev_charge_station_empty` },
	},

	-- titik keluar selang per model pompa: angka = tinggi di atas pivot (dari caticus), vec3 = offset dari pivot.
	-- model lain pakai hose.anchorHeight
	pumpAnchor = {
		[`prop_gas_pump_1a`] = 2.3, [`prop_gas_pump_1b`] = 2.3, [`prop_gas_pump_1c`] = 2.3, [`prop_gas_pump_1d`] = 2.3,
		[`prop_vintage_pump`] = 1.8, [`prop_gas_pump_old2`] = 1.6, [`prop_gas_pump_old3`] = 1.6,
		[`4play_ev_charge_station`] = vec3(0.30, 0.0, 0.36), -- cable gland di sisi kanan bawah
		[`4play_ev_charge_station_empty`] = vec3(0.30, 0.0, 0.36),
	},

	-- Corong / pistol: dipegang di tangan, lalu ditancap ke kendaraan (gaya lc_fuel) dan bisa ditinggal.
	--  hand  = offset x y z + rotasi x y z di tulang tangan kiri (18905), [7] = rotationOrder
	--  tip   = titik sambungan selang di corong (offset model)
	--  rot   = rotasi corong saat menancap di sisi KIRI kendaraan (sisi kanan otomatis +180 di z)
	--  shift = corong dimundurkan sejauh ini (offset model) saat menancap: ujung colokan lebih panjang dari prop lc_fuel
	-- Kalibrasi di game: plugDebug = true lalu /coloktes (lihat client/plug.lua)
	nozzles = {
		petrol = {
			model = `prop_cs_fuel_nozle`,
			hand = { 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, 1 },
			tip = vec3(0.0, -0.033, -0.195),
			rot = vec3(-45.0, 0.0, -90.0),
		},
		-- model dibangun dengan pivot & arah sama dengan prop_eletricpistol lc_fuel (pangkal kabel di bawah pegangan,
		-- colokan ke +Y), jadi angka tangan & tancap lc_fuel dipakai apa adanya
		electric = {
			model = `4play_ev_charge_gun`,
			hand = { 0.13, 0.04, 0.01, -42.0, -115.0, -63.42, 0 },
			tip = vec3(0.0, -0.033, -0.195),
			rot = vec3(-45.0, 0.0, -90.0),
			shift = vec3(0.0, 0.18, 0.0),
		},
	},
	-- titik tancap per model kendaraan (data/plugs.lua, dari lc_fuel); model lain pakai ini.
	--  offset dari tulang tutup tangki: forward / right / up (meter), distance = jarak player ke titik tancap
	plugDefault = { distance = 1.2, nozzleOffset = { forward = 0.0, right = -0.15, up = 0.5 } },
	plugDebug = false,

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
