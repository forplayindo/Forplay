-- SEMENTARA: tes animasi Drink Station. Hapus file ini (dan barisnya di fxmanifest) setelah animasi dipilih.
-- /cafeanim        -> daftar kandidat di F8
-- /cafeanim 3      -> mainkan kandidat 3 (dengan gelas kopi di tangan)
-- /cafeanim 3 0    -> mainkan kandidat 3 tanpa prop
-- /cafeanim 0      -> berhenti

local CANDIDATES = {
    { 'anim@amb@business@meth@meth_monitoring_cooking@cooking@', 'chemical_pour_short_cooker', 'Menuang dari wadah (pendek)' },
    { 'anim@amb@business@meth@meth_monitoring_cooking@cooking@', 'chemical_pour_long_cooker',  'Menuang dari wadah (panjang)' },
    { 'mini@drinking', 'shots_barman_b', 'Barman menuang shot (variasi b)' },
    { 'mini@drinking', 'shots_barman_c', 'Barman menuang shot (variasi c)' },
    { 'anim@amb@nightclub@mini@drinking@bar@drink@beer', 'intro_bartender', 'Bartender ambil botol lalu sodorkan' },
    { 'anim@amb@nightclub@mini@drinking@bar@drink@champagne', 'intro_bartender', 'Bartender sampanye' },
    { 'anim@amb@casino@mini@drinking@bar@drink@heels@base', 'intro_bartender', 'Bartender kasino' },
    { 'anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter', 'Tangan bekerja di meja (meracik)' },
    { 'anim@amb@business@meth@meth_smash_weight_check@', 'break_weigh_v3_char01', 'Menimbang / menyiapkan di meja' },
    { 'anim@amb@business@weed@weed_inspecting_high_dry@', 'weed_inspecting_high_base_inspector', 'Tangan sibuk setinggi dada' },
    { 'amb@prop_human_parking_meter@female@base', 'base_female', 'Pencet tombol mesin (mesin kopi)' },
    { 'amb@prop_human_bum_bin@base', 'base', 'Ambil sesuatu di bawah (es / bahan)' },
}

local prop

local function stop()
    ClearPedTasks(cache.ped)
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
end

RegisterCommand('cafeanim', function(_, args)
    local n = tonumber(args[1])
    if not n then
        print('^3[cafeanim] kandidat:^7')
        for i, c in ipairs(CANDIDATES) do print(('  %2d. %s  (%s / %s)'):format(i, c[3], c[1], c[2])) end
        return lib.notify({ description = 'Daftar kandidat ada di F8. Pakai /cafeanim <nomor>.', type = 'inform' })
    end

    stop()
    if n == 0 then return end

    local c = CANDIDATES[n]
    if not c then return lib.notify({ description = 'Nomor tidak ada.', type = 'error' }) end

    if not DoesAnimDictExist(c[1]) then
        return lib.notify({ description = ('#%d dict tidak ada di game, lewati.'):format(n), type = 'error' })
    end
    local ok = pcall(lib.requestAnimDict, c[1], 5000)
    if not ok or GetAnimDuration(c[1], c[2]) <= 0.0 then
        RemoveAnimDict(c[1])
        return lib.notify({ description = ('#%d clip tidak ada di game, lewati.'):format(n), type = 'error' })
    end

    TaskPlayAnim(cache.ped, c[1], c[2], 3.0, 3.0, -1, 1, 0.0, false, false, false)
    RemoveAnimDict(c[1])

    if args[2] ~= '0' then
        local model = `p_amb_coffeecup_01`
        lib.requestModel(model, 5000)
        prop = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
        AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(model)
    end

    lib.notify({ description = ('#%d %s'):format(n, c[3]), type = 'success' })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then stop() end
end)
