-- Keausan & efek kerusakan (client pengemudi). Semua angka persen (0-100) kecuali disebut lain.
return {
    tick = 1000,          -- ms per pengecekan (hanya saat jadi pengemudi)
    sendEvery = 20,       -- detik; keausan dikumpulkan lalu dikirim ke server sekaligus / saat turun

    -- umur pakai (km jarak nyata) sampai bagian habis dari 100% ke 0%
    life = {
        oil = 1200, coolant = 1500, brakefluid = 1900, transfluid = 2250,
        sparkplugs = 1900, airfilter = 1500, radiator = 3000, clutch = 2250, axle = 3000, brakes = 1200,
        tyre = 900,
    },

    -- efek berantai: bagian aus lebih cepat kalau bagian lain rusak
    chain = {
        oilWhenEngineBelow = 50, oilMult = 2.0,                 -- mesin < 50% -> oli 2x lebih cepat habis
        coolantWhenRadiatorBelow = 50, coolantMult = 3.0,       -- radiator < 50% -> coolant bocor
        sparkWhenFilterBelow = 50, sparkMult = 1.5,
        clutchWhenTransBelow = 20, clutchMult = 1.5,
        brakesWhenFluidBelow = 20, brakesMult = 1.5,
    },

    offroad = { airfilterMult = 3.0, tyreMult = 2.0, suspensionPerKm = 2.0, minSpeed = 5.0 }, -- suspensi turun per km offroad (kendaraan non-offroad)

    hardBrake = { fromKmh = 120, toKmh = 30, window = 3, brakes = { 0.5, 1.5 }, brakefluid = 0.3 },
    brakeAndGas = { seconds = 5, brakes = 1, clutch = 1 },
    downhill = { pitch = -5.0, seconds = 10, brakes = { 1, 2 } },
    burnout = { tyrePerSec = 1.5, transfluidPerSec = 0.3, clutchPerSec = 0.2 },
    drift = { lateral = 6.0, minSpeed = 10.0, tyrePerSec = 0.6 },
    launch = { clutchPerSec = 0.3 },
    highRpm = { rpm = 0.9, seconds = 10, oil = 0.5, sparkplugs = 0.3 },
    landing = { velocity = -8.0, suspension = { 1.5, 4 }, axle = { 0.5, 2 } },
    -- tabrakan: dari turunnya body health dalam 1 tick
    collision = { minDrop = 40.0, radiator = 0.2, brakes = 0.08, suspension = 0.15, axle = 0.1 }, -- x (drop / 10)

    -- kelas yang tidak memakai sistem ini (sepeda, perahu, heli, pesawat, kereta)
    ignoredClasses = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true },
    offroadClass = 9,

    ---------------------------------------------------------------------------
    -- Efek (multiplier handling) per tingkat: Baik, Aus, Rusak, Parah
    ---------------------------------------------------------------------------
    brakeForce = { 1.0, 0.85, 0.65, 0.4 },   -- min(rem, minyak rem)
    traction = { 1.0, 0.92, 0.8, 0.65 },     -- rata-rata keausan ban
    rainLevel = 0.3, rainPenalty = 2.0,      -- hujan: penurunan grip dikali 2
    suspension = { 1.0, 0.9, 0.8, 0.7 },
    power = { 1.0, 0.95, 0.88, 0.78 },       -- dikalikan untuk busi, filter udara, oli

    misfire = { 0, 0, 0.015, 0.04 },         -- peluang per detik mesin tersendat (busi)
    clutchSlip = { 0, 0, 0.01, 0.03 },       -- peluang per detik mesin mati sesaat (kopling)
    steerWobble = { 0, 0, 0.02, 0.05 },      -- peluang per detik setir goyang (as roda)
    brakePull = 0.15,                         -- bias setir saat ngerem keras dengan rem Parah
    overheatEngine = { 0, 0, 0, 1.0 },       -- engine health turun per detik (oli / coolant Parah)
    extraFuel = { 0, 0, 0.01, 0.03 },        -- liter extra per detik (filter udara)
    selfBurst = { below = 20, minSpeed = 25.0, chance = 0.002 }, -- ban gundul pecah sendiri (per detik)

    -- bunyi decit saat ngerem dengan rem Rusak (tingkat 3) / Parah (4). Terdengar pemain sekitar.
    squeal = { level = 3, minSpeed = 5.0, interval = 2500, distance = 40.0, volume = 0.07 },
}
