-- f_petshop client: preview 3D hewan di toko. Ped & kamera dibuat LOKAL (tidak tersinkron),
-- jadi hanya pembeli yang melihatnya.

Preview = {}

local petsById = {}
for _, p in ipairs(Config.Pets) do petsById[p.id] = p end

local cam
local ped = 0
local base     -- vec4: posisi hewan; w = arah hadap awal (kamera ada di depannya)
local heading = 0.0
local zoom = 1.0
local current  -- { cfg, variant }
local token = 0 -- naik tiap ganti hewan / tutup, supaya model yang telat dimuat tidak ikut muncul

local function camCfg(cfg)
    return Config.PreviewCam[cfg and cfg.kind] or Config.PreviewCam.default
end

local function placeCam()
    if not cam or not current then return end
    local c = camCfg(current.cfg)
    local h = math.rad(base.w)
    local d = c.dist * zoom
    SetCamCoord(cam, base.x - math.sin(h) * d, base.y + math.cos(h) * d, base.z + c.height)
    PointCamAtCoord(cam, base.x, base.y, base.z + c.look)
end

local props = {} -- aksesoris yang sedang dicoba di hewan preview

local function deletePed()
    Accessories.detach(props)
    props = {}
    if ped ~= 0 and DoesEntityExist(ped) then DeleteEntity(ped) end
    ped = 0
end

-- pasang aksesoris (coba-coba di toko) ke hewan preview
local function applyWorn()
    Accessories.detach(props)
    props = {}
    if ped == 0 or not current then return end
    local worn = current.worn or {}
    if worn.collar then
        SetPedComponentVariation(ped, Config.CollarComponent, 0, worn.collar, 0)
    elseif Accessories.collarCount(ped) > 0 then
        SetPedComponentVariation(ped, Config.CollarComponent, 0, 0, 0)
    end
    props = Accessories.attach(ped, current.cfg.model, worn)
    SendNUIMessage({ action = 'previewInfo', data = { collars = Accessories.collarCount(ped) } })
end

local function spawn(cfg, variant)
    token += 1
    local my = token
    local model = joaat(cfg.model)
    if not IsModelInCdimage(model) then return end
    if not pcall(lib.requestModel, model, 10000) or my ~= token or not cam then return end

    deletePed()
    ped = CreatePed(28, model, base.x, base.y, base.z, heading, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    FreezeEntityPosition(ped, true)
    if cfg.variants then SetPedComponentVariation(ped, cfg.variants.comp, 0, variant, 0) end
    placeCam()
    applyWorn()
end

function Preview.isOpen() return cam ~= nil end

---@param hide number[]? entity lain yang disembunyikan selama preview (mis. penjaga toko)
function Preview.open(hide)
    if cam then return end
    hide = hide or {}
    local p = Config.Shop.preview
    if p then
        base = vec4(p.x, p.y, p.z, p.w)
    else
        local pos = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 3.0, 0.0)
        base = vec4(pos.x, pos.y, pos.z, (GetEntityHeading(cache.ped) + 180.0) % 360.0)
    end
    local found, z = GetGroundZFor_3dCoord(base.x, base.y, base.z + 1.0, false)
    if found then base = vec4(base.x, base.y, z, base.w) end

    heading = (base.w - 35.0) % 360.0 -- sedikit menyamping supaya bentuk badannya terlihat
    zoom = 1.0
    current = nil
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', base.x, base.y, base.z + 1.0, 0.0, 0.0, 0.0, 40.0, false, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 600, true, false)

    CreateThread(function()
        while cam do
            SetEntityLocallyInvisible(cache.ped) -- pemain tidak menghalangi kamera
            for _, ent in ipairs(hide) do
                if DoesEntityExist(ent) then SetEntityLocallyInvisible(ent) end
            end
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)
end

function Preview.close()
    token += 1
    deletePed()
    current = nil
    if cam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(cam, false)
        cam = nil
    end
end

---@param id string id hewan di Config.Pets
---@param variant number? nomor warna
---@param worn table? aksesoris yang ditampilkan { [slot] = prop | nomor kalung }
function Preview.show(id, variant, worn)
    local cfg = petsById[id]
    if not cam or not cfg then return end
    variant = math.floor(tonumber(variant) or 0)
    if current and current.cfg == cfg and ped ~= 0 and DoesEntityExist(ped) then
        -- hewan sama, cuma ganti warna / aksesoris
        current.variant, current.worn = variant, worn
        if cfg.variants then SetPedComponentVariation(ped, cfg.variants.comp, 0, variant, 0) end
        CreateThread(applyWorn)
        return
    end
    current = { cfg = cfg, variant = variant, worn = worn }
    CreateThread(function() spawn(cfg, variant) end)
end

function Preview.rotate(dx)
    heading = (heading + (tonumber(dx) or 0) * 0.45) % 360.0
    if ped ~= 0 and DoesEntityExist(ped) then SetEntityHeading(ped, heading) end
end

function Preview.zoom(dir)
    zoom = math.max(0.6, math.min(1.8, zoom + ((tonumber(dir) or 0) > 0 and 0.1 or -0.1)))
    placeCam()
end

-- Ambil posisi preview: berdiri di tempat hewan akan tampil, menghadap ke arah kamera.
if Config.Debug then
    RegisterCommand('petpreview', function()
        local c = GetEntityCoords(cache.ped)
        local text = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, GetEntityHeading(cache.ped))
        lib.setClipboard(text)
        lib.notify({ description = ('Disalin: %s → tempel ke Config.Shop.preview'):format(text), type = 'success' })
    end, false)
end
