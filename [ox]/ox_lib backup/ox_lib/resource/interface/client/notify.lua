--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@alias NotificationPosition 'top' | 'top-right' | 'top-left' | 'bottom' | 'bottom-right' | 'bottom-left' | 'center-right' | 'center-left'
---@alias NotificationType 'info' | 'warning' | 'success' | 'error'
---@alias IconAnimationType 'spin' | 'spinPulse' | 'spinReverse' | 'pulse' | 'beat' | 'fade' | 'beatFade' | 'bounce' | 'shake'

---@class NotifyProps
---@field id? string
---@field title? string
---@field description? string
---@field duration? number
---@field showDuration? boolean
---@field position? NotificationPosition
---@field type? NotificationType
---@field style? { [string]: any }
---@field icon? string | { [1]: IconProp, [2]: string }
---@field iconAnimation? IconAnimationType
---@field iconColor? string
---@field alignIcon? 'top' | 'center'
---@field sound? { bank?: string, set: string, name: string }

local settings = require 'resource.settings'
local offsetConfig = require 'resource.notification_offset'

--- Friendly names from the config file mapped onto ox_lib's own.
--- 'top-middle' reads better in a config than 'top', but the CSS class
--- and every existing caller use 'top'.
local ALIASES = {
    ['top-middle']    = 'top',
    ['bottom-middle'] = 'bottom',
    ['top-center']    = 'top',
    ['bottom-center'] = 'bottom',
    ['middle-right']  = 'center-right',
    ['middle-left']   = 'center-left',
}

local VALID = {
    ['top'] = true, ['top-right'] = true, ['top-left'] = true,
    ['bottom'] = true, ['bottom-right'] = true, ['bottom-left'] = true,
    ['center-right'] = true, ['center-left'] = true,
}

---@param value string?
---@return string?
local function normalise(value)
    if not value then return nil end
    value = ALIASES[value] or value
    return VALID[value] and value or nil
end

local configuredPosition = normalise(offsetConfig.position)

if offsetConfig.position and not configuredPosition then
    warn(("notification_offset.lua: '%s' is not a valid position; falling back to top-right.")
        :format(tostring(offsetConfig.position)))
end

--- Pixels in from the edge for a given position.
---@param position string
---@return number x, number y
local function offsetFor(position)
    local base = offsetConfig.offset or {}
    local over = offsetConfig.overrides and offsetConfig.overrides[position]

    -- An override is looked up by the RESOLVED name, so a config using
    -- 'top-middle' in `position` and 'top' in `overrides` still matches.
    if not over and offsetConfig.overrides then
        for key, value in pairs(offsetConfig.overrides) do
            if normalise(key) == position then over = value break end
        end
    end

    over = over or {}
    return tonumber(over.x) or tonumber(base.x) or 18,
           tonumber(over.y) or tonumber(base.y) or 18
end

---`client`
---@param data NotifyProps
---@diagnostic disable-next-line: duplicate-set-field
function lib.notify(data)
    local sound = settings.notification_audio and data.sound
    local payload = table.clone(data)
    payload.sound = nil
    -- Priority: forced config > the caller's explicit choice > the
    -- player's own setting from /ox_lib > the config default.
    if offsetConfig.force and configuredPosition then
        payload.position = configuredPosition
    else
        payload.position = normalise(payload.position)
            or settings.notification_position
            or configuredPosition
            or 'top-right'
    end

    payload.offsetX, payload.offsetY = offsetFor(payload.position)

    SendNUIMessage({
        action = 'notify',
        data = payload
    })

    if not sound then return end

    if sound.bank then lib.requestAudioBank(sound.bank) end

    local soundId = GetSoundId()
    PlaySoundFrontend(soundId, sound.name, sound.set, true)
    ReleaseSoundId(soundId)

    if sound.bank then ReleaseNamedScriptAudioBank(sound.bank) end
end

---@class DefaultNotifyProps
---@field title? string
---@field description? string
---@field duration? number
---@field position? NotificationPosition
---@field status? 'info' | 'warning' | 'success' | 'error'
---@field id? number

---@param data DefaultNotifyProps
function lib.defaultNotify(data)
    -- Backwards compat for v3
    data.type = data.status
    if data.type == 'inform' then data.type = 'info' end
    return lib.notify(data --[[@as NotifyProps]])
end

RegisterNetEvent('ox_lib:notify', lib.notify)
RegisterNetEvent('ox_lib:defaultNotify', lib.defaultNotify)
