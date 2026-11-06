-- Minimap: square f_hud mask (stream/rectangle.ytd) on the postal map tiles streamed by [standalone]/f_postalcode.
-- The old GTA VI style (minimap.gfx + minimap.ytd) is kept in resources/backups/f_hud_gta6_minimap.
-- Also feeds the NUI overlay (waypoint distance) and the layout of the status block / location card around the map.

local Minimap = {}

local cfg = Config.Minimap
local placement = ''
local texturesLoaded = false
local rect = { left = 0, top = 0, width = 0, height = 0 }
local debugOutline = false
local lastSent

local function loadTextures()
    if texturesLoaded then return end
    -- square radar mask from stream/rectangle.ytd
    RequestStreamedTextureDict('rectangle', false)
    local deadline = GetGameTimer() + 5000
    while not HasStreamedTextureDictLoaded('rectangle') and GetGameTimer() < deadline do
        Wait(10)
    end
    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'rectangle', 'radarmasksm')
    AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'rectangle', 'radarmasksm')
    local c = cfg.routeColor
    ReplaceHudColourWithRgba(142, c[1], c[2], c[3], 255)
    texturesLoaded = true
end

---Positions the radar for the current aspect ratio / safezone. Returns true when it moved.
---@param force? boolean
---@return boolean
function Minimap.Place(force)
    local aspect = GetAspectRatio(false)
    SetScriptGfxAlign(76, 66) -- L, B
    local originX = GetScriptGfxPosition(0.0, 0.0)
    ResetScriptGfxAlign()
    local margin = (1.0 - GetSafeZoneSize()) * 0.5
    local key = ('%.4f|%.4f|%.4f'):format(aspect, originX, margin)
    if key == placement and not force then return false end
    placement = key
    local scale = aspect > 0.0 and 1.7777 / aspect or 1.0
    -- minimap = player arrow/blips, minimap_mask = visible map area, minimap_blur = map background.
    -- All three get the same x shift so they stay aligned (and no other resource keeps a stale mask/blur).
    local function place(component, x, y, w, h)
        SetMinimapComponentPosition(component, 'L', 'B', (originX + x) * scale - originX, y, w, h)
    end
    local m, b, a = cfg.mask, cfg.blur, cfg.arrow
    local lift = cfg.lift or 0.0
    place('minimap', cfg.x + a.x, cfg.y + a.y - lift, cfg.width, cfg.height)
    -- mask y is relative to the minimap (it follows it already); minimap and blur are absolute, so only they get lifted
    place('minimap_mask', cfg.x + m.x, m.y, m.w, m.h)
    place('minimap_blur', cfg.x + b.x, b.y - lift, b.w, b.h)
    SetMinimapClipType(0)
    -- screen fractions of the visible map for the NUI (area is in screen-height units, like gta6_hud's vh)
    local o, ar = cfg.overlayOffset, cfg.area
    rect.width = ar.w / aspect + o.w
    rect.height = ar.h + o.h
    rect.left = ar.left / aspect + o.x
    rect.top = 1.0 - ar.bottom - lift - ar.h + o.y
    return true
end

---Full (re)load: textures, placement, radar refresh.
function Minimap.Load()
    loadTextures()
    Minimap.Place(true)
    SetBlipAlpha(GetNorthRadarBlip(), cfg.showNorth and 255 or 0)
    SetBigmapActive(true, false)
    Wait(50)
    SetBigmapActive(false, false)
end

-- 0 = day, 1 = full night, ramps at dusk/dawn
local function getNightFactor()
    local h = GetClockHours() + GetClockMinutes() / 60
    local n = cfg.night
    local f
    if h >= n.duskEnd or h < n.dawnStart then
        f = 1.0
    elseif h >= n.duskStart then
        f = (h - n.duskStart) / (n.duskEnd - n.duskStart)
    elseif h < n.dawnEnd then
        f = 1.0 - (h - n.dawnStart) / (n.dawnEnd - n.dawnStart)
    else
        f = 0.0
    end
    return math.floor(f * 20 + 0.5) / 20
end

local function getWaypointDistance()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return nil end
    local meters = GetGpsBlipRouteLength()
    if not meters or meters <= 0 then
        local c = GetBlipInfoIdCoord(blip)
        meters = #(GetEntityCoords(cache.ped).xy - c.xy)
    end
    if meters < 1000 then
        return ('%d m'):format(math.floor(meters / 10 + 0.5) * 10)
    end
    return (('%.1f km'):format(meters / 1000):gsub('%.', ','))
end

-- The game's satnav (distance + direction arrow, bottom-left) is replaced by our own distance label.
-- With the vanilla minimap.gfx the game can re-show the satnav on a route, so HIDE_SATNAV is re-sent every tick
-- (the patched GTA VI gfx renamed SHOW_SATNAV; it is in resources/backups/f_hud_gta6_minimap).
local minimapMovie
local function hideSatnav()
    if not minimapMovie or not HasScaleformMovieLoaded(minimapMovie) then
        minimapMovie = RequestScaleformMovie('minimap')
        return
    end
    BeginScaleformMovieMethod(minimapMovie, 'HIDE_SATNAV')
    EndScaleformMovieMethod()
end

local function pushOverlay()
    local data = {
        rect = rect,
        radar = not IsRadarHidden(),
        night = getNightFactor(),
        nightOpacity = cfg.night.opacity,
        distance = getWaypointDistance(),
        radius = cfg.radius,
        frame = cfg.frame,
        statusGap = cfg.statusGap,
        coverRight = cfg.coverRight or 0,
        debug = debugOutline,
    }
    local encoded = json.encode(data)
    if encoded == lastSent then return end
    lastSent = encoded
    client.SendReactMessage('ui:setGta6Map', data)
end

CreateThread(function()
    while true do
        if client.load and client.uiLoad then
            if Minimap.Place() then
                SetBigmapActive(true, false)
                Wait(0)
                SetBigmapActive(false, false)
            end
            SetRadarZoom(cfg.zoom)
            hideSatnav()
            pushOverlay()
        end
        Wait(500)
    end
end)

-- Kalibrasi overlay: garis merah = area yang NUI anggap minimap. Atur Config.Minimap.overlayOffset bila meleset.
RegisterCommand('hudmapdebug', function()
    debugOutline = not debugOutline
    lastSent = nil
    if debugOutline then
        local w, h = GetActiveScreenResolution()
        print(('[f_hud] minimap rect px: left=%d top=%d width=%d height=%d | safezone=%.3f'):format(
            math.floor(rect.left * w), math.floor(rect.top * h), math.floor(rect.width * w),
            math.floor(rect.height * h), GetSafeZoneSize()))
    end
end, false)

-- Live tuning: /hudmapset <x|y|width|height|mask.x|mask.y|mask.w|mask.h|blur.*|overlayOffset.*> <angka>
RegisterCommand('hudmapset', function(_, args)
    local function fmt(t) return ('{ x = %s, y = %s, w = %s, h = %s }'):format(t.x, t.y, t.w, t.h) end
    local path = args[1]
    if path then
        -- accepts "mask.h 0.25", "mask.h 0,25" and "mask.h=0.25"
        local raw = args[2]
        if not raw then path, raw = path:match('^([^=]+)=(.+)$') end
        local value = raw and tonumber((raw:gsub(',', '.')))
        local group, key = (path or ''):match('^(%a+)%.(%a+)$')
        local tbl = group and cfg[group] or cfg
        key = key or path
        if not value or type(tbl) ~= 'table' or type(tbl[key]) ~= 'number' then
            print(('[f_hud] tidak dikenali: "%s". Contoh: /hudmapset mask.h 0.25  (x, y, width, height, mask.x/y/w/h, blur.x/y/w/h, arrow.x/y, radius, overlayOffset.x/y/w/h)'):format(table.concat(args, ' ')))
            return
        end
        tbl[key] = value
        Minimap.Place(true)
        SetBigmapActive(true, false)
        Wait(0)
        SetBigmapActive(false, false)
        lastSent = nil
    end
    print(('[f_hud] x = %s, y = %s, width = %s, height = %s'):format(cfg.x, cfg.y, cfg.width, cfg.height))
    print('[f_hud] mask = ' .. fmt(cfg.mask) .. ', blur = ' .. fmt(cfg.blur) .. ', overlayOffset = ' .. fmt(cfg.overlayOffset))
    print(('[f_hud] arrow = { x = %s, y = %s }, radius = %s'):format(cfg.arrow.x, cfg.arrow.y, cfg.radius))
end, false)

return Minimap
