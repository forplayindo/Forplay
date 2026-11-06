-- sementara: /nelayanprop [nama] memunculkan prop lokal di depan pemain; tanpa nama = semua berjajar
local PROPS = {
    tangan = 'f_nelayan_jaring_tangan',
    lempar = 'f_nelayan_jaring_lempar',
    laut   = 'f_nelayan_jaring_laut',
    ikan   = 'f_nelayan_jaring_ikan',
    peti   = 'f_nelayan_peti_ikan',
    kosong = 'f_nelayan_peti_kosong',
    tumpuk = 'f_nelayan_peti_tumpuk',
}
local ORDER = { 'tangan', 'peti', 'kosong', 'tumpuk', 'ikan', 'lempar', 'laut' }
local spawned = {}

local function clear()
    for _, obj in ipairs(spawned) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    spawned = {}
end

local function place(model, forward, side)
    lib.requestModel(model, 5000)
    local ped = cache.ped
    local pos = GetOffsetFromEntityInWorldCoords(ped, side, forward, 0.0)
    local _, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    local obj = CreateObject(joaat(model), pos.x, pos.y, groundZ, false, false, false)
    SetEntityHeading(obj, GetEntityHeading(ped))
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    spawned[#spawned + 1] = obj
end

RegisterNetEvent('f_nelayan:client:propTest', function(name)
    clear()
    if name == 'hapus' then return end
    if name == 'semua' then
        local side = -6.0
        for _, key in ipairs(ORDER) do
            place(PROPS[key], key == 'laut' and 9.0 or 4.0, key == 'laut' and 0.0 or side)
            if key ~= 'laut' then side = side + 2.0 end
        end
        lib.notify({ description = 'Prop nelayan dimunculkan (/nelayanprop hapus untuk menghapus)', type = 'inform' })
        return
    end
    local model = PROPS[name]
    if not model then
        lib.notify({ description = 'Nama prop: tangan, lempar, laut, ikan, peti, kosong, tumpuk, hapus', type = 'error' })
        return
    end
    place(model, name == 'laut' and 6.0 or 2.0, 0.0)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clear() end
end)
