---
--[[ Blur quality manager
     Measures the REAL game FPS (GetFrameCount delta, once every 2s -> ~0.00ms)
     and tells the NUI blur layer which quality tier to use.
     Players can override it with /hudblur (saved per player with KVP). ]]
---

local Blur = {}
local Utils = require 'modules.utils.client'

local cfg = Config.Blur or {}
local KVP_KEY = 'hud_blur_mode'
local ORDER = { off = 0, low = 1, medium = 2, high = 3 }
local VALID = { auto = true, high = true, medium = true, low = true, off = true }

local mode = GetResourceKvpString(KVP_KEY) or cfg.default or 'auto'
if not VALID[mode] then mode = 'auto' end

local autoTier = 'medium'
local lastSent = nil
local pending, pendingCount = nil, 0

local function send(tier)
    if tier == lastSent then return end
    lastSent = tier
    SendNuiMessage(('{"action":"ui:setBlurQuality","data":"%s"}'):format(tier))
end

-- alasan blur ditahan: hidden (HUD tidak tampil / pause menu), faded (layar gelap) -> off; settings -> pause (frame terakhir dibiarkan)
local suspended = {}

--- Tier pilihan pemain / auto, tanpa melihat status HUD (dipakai juga oleh f_chat, ox_lib, Renewed-Banking)
local function baseTier()
    if cfg.enabled == false then return 'off' end
    if mode ~= 'auto' then return mode end
    return autoTier
end

local function currentTier()
    if not client.load or suspended.hidden or suspended.faded then return 'off' end
    if suspended.settings then return 'pause' end
    return baseTier()
end

---@param reason 'hidden' | 'settings' | 'faded'
---@param state boolean
function Blur.Suspend(reason, state)
    suspended[reason] = state or nil
    if client.uiLoad then send(currentTier()) end
end

--- Force re-sending the tier (e.g. after the UI was reloaded)
function Blur.Resend()
    lastSent = nil
    send(currentTier())
end

---Pick a tier from FPS. Going UP needs a safety margin so it does not flip-flop.
local function tierFromFps(fps, cur)
    local t = cfg.autoFps or { high = 75, medium = 45, low = 30 }
    local raw = (fps >= t.high and 'high') or (fps >= t.medium and 'medium') or (fps >= t.low and 'low') or 'off'
    if raw == 'high' and not cfg.autoHigh then raw = 'medium' end -- auto paling tinggi medium; high hanya lewat /hudblur high
    if ORDER[raw] > ORDER[cur] then
        local need = t[raw] + 8
        if fps < need then return cur end
    end
    return raw
end

CreateThread(function()
    local lastFrames, lastTime = GetFrameCount(), GetGameTimer()
    while true do
        Wait(2000)
        local frames, now = GetFrameCount(), GetGameTimer()
        local fps = (frames - lastFrames) * 1000 / math.max(1, now - lastTime)
        lastFrames, lastTime = frames, now

        local faded = IsScreenFadedOut()
        if (suspended.faded or false) ~= faded then suspended.faded = faded or nil end
        if not client.uiLoad then
            lastSent = nil -- UI not ready yet, send again once it is
        elseif IsPauseMenuActive() or faded or not client.load then
            send(currentTier()) -- off / pause, FPS di menu tidak dihitung
        else
            if mode == 'auto' and cfg.enabled ~= false then
                local target = tierFromFps(fps, autoTier)
                if target ~= autoTier then
                    -- confirm on the next sample (4s) before switching; 'off' needs 3 samples
                    if pending == target then pendingCount = pendingCount + 1 else pending, pendingCount = target, 1 end
                    if pendingCount >= (target == 'off' and 3 or 2) then
                        autoTier, pending, pendingCount = target, nil, 0
                    end
                else
                    pending, pendingCount = nil, 0
                end
            end
            send(currentTier())
        end
        -- let other resources (f_chat, ox_lib, Renewed-Banking) follow the same blur tier
        TriggerEvent('0r-hud:blurTier', baseTier())
    end
end)

-- /hudblur [auto|high|medium|low|off]
if cfg.command then
    RegisterCommand(cfg.command, function(_, args)
        local m = args[1] and args[1]:lower()
        if not m or not VALID[m] then
            Utils.Notify(('HUD blur: %s  (auto / high / medium / low / off)'):format(mode), 'inform')
            return
        end
        mode = m
        SetResourceKvp(KVP_KEY, m)
        send(currentTier())
        TriggerEvent('0r-hud:blurTier', baseTier())
        Utils.Notify(('HUD blur: %s'):format(m), 'success')
    end, false)
end

return Blur
