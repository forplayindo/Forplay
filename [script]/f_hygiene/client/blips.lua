-- blip statis (dibuat sekali di awal, bukan loop), satu-satu sesuai titik yang terdaftar di
-- Config.ToiletLocations/ShowerLocations - jumlahnya sedikit jadi tidak perlu di-manage dinamis
local function CreateLocationBlips(locations, cfg)
    if not cfg or not cfg.show then return end

    for _, loc in ipairs(locations) do
        local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
        SetBlipSprite(blip, cfg.sprite)
        SetBlipColour(blip, cfg.color or 0)
        SetBlipScale(blip, cfg.scale or 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(cfg.name or '')
        EndTextCommandSetBlipName(blip)
    end
end

CreateThread(function()
    CreateLocationBlips(Config.ToiletLocations, Config.Blips.Toilet)
    CreateLocationBlips(Config.ShowerLocations, Config.Blips.Shower)
end)
