local config = require 'f_staticemitters.config'
local currentGameBuild = GetGameBuildNumber()
local setStaticEmitterEnabled = SetStaticEmitterEnabled

if not config.enabled then return end

-- lib.print.warn('Static emitters enabled ! config: f_smallresources/f_staticemitters/config.lua')

local emitterGroupsData = {}

local function isEmitterDisabled(groupOptions, emitterOptions)
    return config.disableAll or groupOptions.disable or emitterOptions.disable
end

-- dijalankan untuk SEMUA pemain (dulu hanya ikut terpasang kalau admin, karena ada di registerMenus)
local function applyEmitters()
    for gameBuild, emitterGroups in pairs(config.gameBuild) do
        if currentGameBuild >= gameBuild then
            for _, groupOptions in pairs(emitterGroups) do
                for emitterName, emitterOptions in pairs(groupOptions.emitters) do
                    setStaticEmitterEnabled(emitterName, not isEmitterDisabled(groupOptions, emitterOptions))
                end
            end
        end
    end
end

local function registerMenus()
    local mainOptions = {}
    local submenus = {}

    for gameBuild, emitterGroups in pairs(config.gameBuild) do
        if currentGameBuild >= gameBuild then
            for emitterGroup in pairs(emitterGroups) do
                if not mainOptions[emitterGroup] then
                    local groupTitle = emitterGroup:gsub('%f[%a].', string.upper)
                    mainOptions[emitterGroup] = {
                        label = groupTitle,
                        description = ('GameBuild: %s'):format(gameBuild),
                        icon = 'folder',
                    }
                    submenus[#submenus + 1] = emitterGroup
                end
            end
        end
    end

    local mainMenuOptions = {}
    for i = 1, #submenus do
        mainMenuOptions[i] = mainOptions[submenus[i]]
    end

    lib.registerMenu({
        id = 'static_emitters_menu',
        title = 'Static Emitters Menu',
        position = 'top-right',
        options = mainMenuOptions,
    }, function(selected)
        local group = submenus[selected]
        if group then
            lib.showMenu('submenu_' .. group, 1)
        end
    end)

    for gameBuild, emitterGroups in pairs(config.gameBuild) do
        if currentGameBuild >= gameBuild then
            for emitterGroup, emitterGroupOptions in pairs(emitterGroups) do
                local submenuOptions = {}
                local optionIndex = 0
                local emitters = {}

                for emitterName, emitterOptions in pairs(emitterGroupOptions.emitters) do
                    optionIndex = optionIndex + 1
                    local emitterDisable = isEmitterDisabled(emitterGroupOptions, emitterOptions)
                    local pos = emitterOptions.position
                    local posStr = ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z)

                    submenuOptions[optionIndex] = {
                        label = emitterName,
                        description = ('%s | %s'):format(emitterDisable and 'DISABLED' or 'enabled', posStr),
                        icon = emitterDisable and 'toggle-off' or 'toggle-on',
                    }

                    emitters[#emitters + 1] = {
                        name = emitterName,
                        position = pos,
                        disabled = emitterDisable,
                    }
                end

                emitterGroupsData[emitterGroup] = emitters

                lib.registerMenu({
                    id = 'submenu_' .. emitterGroup,
                    title = emitterGroup:gsub('%f[%a].', string.upper),
                    position = 'top-right',
                    menu = 'static_emitters_menu',
                    options = submenuOptions,
                    onClose = function()
                        lib.showMenu('static_emitters_menu')
                    end,
                }, function(selected)
                    local idx = 0
                    for emName in pairs(emitterGroupOptions.emitters) do
                        idx = idx + 1
                        if idx == selected then
                            local pos = emitterGroupOptions.emitters[emName].position
                            local posStr = ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z)
                            if config.menu.copyToClipboard then lib.setClipboard(posStr) end
                            SetEntityCoords(cache.ped, pos.x, pos.y, pos.z, true, false, false, false)
                            break
                        end
                    end
                end)
            end
        end
    end
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end

    applyEmitters()

    local isAllowed = lib.callback.await('f_staticemitters:server:IsPlayerAceAllowed', false)

    if isAllowed then
        registerMenus()
        RegisterCommand('staticemitters', function()
            lib.showMenu('static_emitters_menu', 1)
            CreateThread(function()
                while lib.getOpenMenu() do
                    local playerPos = GetEntityCoords(cache.ped)
                    for _, group in pairs(emitterGroupsData) do
                        for i = 1, #group do
                            local em = group[i]
                            local pos = em.position
                            if #(playerPos - pos) < 200.0 then
                                local color = em.disabled and { r = 255, g = 50, b = 50 } or { r = 50, g = 255, b = 50 }
                                DrawMarker(28, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, color.r, color.g, color.b, 100, false, false, 0, true, false, false, false)
                                qbx.drawText3d({coords = pos, text = em.name})
                            end
                        end
                    end
                    Wait(0)
                end
            end)
        end, false)
    end
end)
