--[[ Renewed-Banking · blur quality manager
     - Follows 0r-hud-v3's tier when the HUD is running (so /hudblur also
       controls the bank UI), otherwise measures the real game FPS itself.
     - FPS is read once every 2s from GetFrameCount() -> ~0.00ms resmon.
     - Players can override with /bankblur (saved per player). ]]

local cfg = Config.Blur or {}
local KVP_KEY = 'renewed-banking:blur'
local ORDER = { off = 0, low = 1, medium = 2, high = 3 }
local VALID = { auto = true, high = true, medium = true, low = true, off = true }

local mode = GetResourceKvpString(KVP_KEY) or cfg.default or 'auto'
if not VALID[mode] then mode = 'auto' end

local autoTier, lastSent = 'medium', nil
local pending, pendingCount = nil, 0
local hudTier, hudSeen = nil, 0

local function push(tier)
    if tier == lastSent then return end
    lastSent = tier
    SendNuiMessage(('{"action":"blurQuality","data":"%s"}'):format(tier))
end

local function currentTier()
    if cfg.enabled == false then return 'off' end
    if mode ~= 'auto' then return mode end
    if hudTier and GetGameTimer() - hudSeen < 10000 then return hudTier end
    return autoTier
end

-- broadcast by 0r-hud-v3 every 2s
AddEventHandler('0r-hud:blurTier', function(tier)
    if ORDER[tier] then
        hudTier, hudSeen = tier, GetGameTimer()
        if mode == 'auto' then push(currentTier()) end
    end
end)

local function tierFromFps(fps, cur)
    local t = cfg.autoFps or { high = 75, medium = 45, low = 30 }
    local raw = (fps >= t.high and 'high') or (fps >= t.medium and 'medium') or (fps >= t.low and 'low') or 'off'
    if raw == 'high' and not cfg.autoHigh then raw = 'medium' end -- sama dengan f_hud: auto paling tinggi medium
    if ORDER[raw] > ORDER[cur] and fps < t[raw] + 8 then return cur end
    return raw
end

CreateThread(function()
    Wait(1500)
    lastSent = nil
    local lastFrames, lastTime = GetFrameCount(), GetGameTimer()
    while true do
        Wait(2000)
        local frames, now = GetFrameCount(), GetGameTimer()
        local fps = (frames - lastFrames) * 1000 / math.max(1, now - lastTime)
        lastFrames, lastTime = frames, now
        if not IsPauseMenuActive() and not IsScreenFadedOut() then
            local target = tierFromFps(fps, autoTier)
            if target ~= autoTier then
                if pending == target then pendingCount = pendingCount + 1 else pending, pendingCount = target, 1 end
                if pendingCount >= (target == 'off' and 3 or 2) then autoTier, pending, pendingCount = target, nil, 0 end
            else
                pending, pendingCount = nil, 0
            end
            push(currentTier())
        end
    end
end)

if cfg.command then
    RegisterCommand(cfg.command, function(_, args)
        local m = args[1] and args[1]:lower()
        if not m or not VALID[m] then
            lib.notify({ description = ('Bank blur: %s  (auto / high / medium / low / off)'):format(mode), type = 'inform' })
            return
        end
        mode = m
        SetResourceKvp(KVP_KEY, m)
        push(currentTier())
        lib.notify({ description = ('Bank blur: %s'):format(m), type = 'success' })
    end, false)
end
