-- Contoh: ketik /spawntugu untuk memunculkan tugu + tiang bendera di depan kamu.
-- Kedua prop sudah punya collision; FreezeEntityPosition membuatnya diam (tidak bisa didorong/ditabrak jatuh).
local SOCKET_Z = 0.46  -- tinggi dasar lubang soket di dalam tugu (meter)

local function loadModel(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) then
        print(('[tugu_flag] model %s tidak ditemukan, cek stream/ dan ytyp'):format(name))
        return nil
    end
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    return hash
end

RegisterCommand('spawntugu', function()
    local ped = PlayerPedId()
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
    local heading = GetEntityHeading(ped)

    local pedestalHash = loadModel('tugu_flag_pedestal')
    local poleHash = loadModel('flag_on_pole')
    if not pedestalHash or not poleHash then return end

    local pedestal = CreateObject(pedestalHash, pos.x, pos.y, pos.z, true, false, false)
    SetEntityHeading(pedestal, heading)
    PlaceObjectOnGroundProperly(pedestal)
    FreezeEntityPosition(pedestal, true)

    local base = GetEntityCoords(pedestal)
    local pole = CreateObject(poleHash, base.x, base.y, base.z + SOCKET_Z, true, false, false)
    SetEntityHeading(pole, heading)
    FreezeEntityPosition(pole, true)

    SetModelAsNoLongerNeeded(pedestalHash)
    SetModelAsNoLongerNeeded(poleHash)
end, false)
