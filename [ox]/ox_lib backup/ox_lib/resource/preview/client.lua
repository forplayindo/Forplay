--[[
    Preview commands for the redesigned ox_lib interface.

    One command per element, so a change to a single component can be
    looked at on its own rather than sitting inside a sequence that has
    already moved on. Notifications are the exception: the four types are
    only meaningful next to each other, so they share one command.

    Every name is prefixed `ui` to keep them out of the way of the rest
    of the server -- a bare /notify or /menu is exactly the sort of name
    another resource takes.

    Type /uihelp for the list.
]]

--- Registration order, which is also the order /uiall walks.
---@type table[]
local previews = {}

--- The radial entries the preview adds, named once so registering them
--- and taking them out again cannot drift apart.
local RADIAL_PREVIEW_IDS = {
    'ui_preview_a', 'ui_preview_b', 'ui_preview_c', 'ui_preview_d',
}

--- Register a preview command.
---@param name string without the `ui` prefix
---@param description string
---@param fn fun()
---@param opts? table { tour = false } to keep it out of /uiall
local function preview(name, description, fn, opts)
    local command = 'ui' .. name

    previews[#previews + 1] = {
        command = command,
        description = description,
        fn = fn,
        tour = not (opts and opts.tour == false),
    }

    RegisterCommand(command, function() fn() end, false)
    TriggerEvent('chat:addSuggestion', '/' .. command, description)
end

-- ────────────────────────────────────────────────────────────────────
--  Teardown
--
--  Everything ox_lib can have on screen, shut in one call. Each close
--  guards on its own state, so calling all of them when nothing is open
--  costs nothing and means the tour never has to remember what it just
--  showed.
-- ────────────────────────────────────────────────────────────────────

local function closeEverything()
    lib.closeInputDialog()
    lib.closeAlertDialog('cancel')

    if lib.getOpenContextMenu() then lib.hideContext() end
    if lib.getOpenMenu() then lib.hideMenu() end
    if lib.progressActive() then lib.cancelProgress() end
    if lib.skillCheckActive() then lib.cancelSkillCheck() end
    if lib.isTextUIOpen() then lib.hideTextUI() end

    lib.hideRadial()

    -- Radial items are registered, not "shown", so hiding the wheel
    -- leaves them in it. Without this the tour would add four entries to
    -- everyone's radial menu and never take them out again.
    -- removeRadialItem on an id that is not there simply finds nothing.
    for _, id in ipairs(RADIAL_PREVIEW_IDS) do
        lib.removeRadialItem(id)
    end
end

-- ────────────────────────────────────────────────────────────────────
--  Notifications
--
--  All four types in one go: their whole point is the difference
--  between them, and that is only visible side by side.
-- ────────────────────────────────────────────────────────────────────

preview('notify', 'Every notification type, one after another', function()
    local types = {
        { type = 'info',    title = 'Information', icon = 'circle-info',
          description = 'A neutral message. Nothing is wrong.' },
        { type = 'success', title = 'Success',     icon = 'check',
          description = 'The thing you asked for happened.' },
        { type = 'warning', title = 'Warning',     icon = 'triangle-exclamation',
          description = 'It worked, but read this before carrying on.' },
        { type = 'error',   title = 'Error',       icon = 'xmark',
          description = 'It did not work, and here is why.' },
    }

    for _, entry in ipairs(types) do
        lib.notify({
            title = entry.title,
            description = entry.description,
            type = entry.type,
            icon = entry.icon,
            position = 'top-right',
            duration = 6000,
        })
        Wait(350)
    end
end)

-- ────────────────────────────────────────────────────────────────────
--  Input dialog — one command per field type
--
--  Separately, because a field is easiest to judge when it is the only
--  thing on screen: the focus ring, the floating label and the spacing
--  all have to look right on their own before they look right in a row.
-- ────────────────────────────────────────────────────────────────────

preview('input', 'The input dialog, with every field type', function()
    -- One dialog rather than one per field: the fields only have to look
    -- right NEXT to each other, and a form is how anybody actually meets
    -- them.
    local result = lib.inputDialog('Character Registration', {
        { type = 'input', label = 'First Name', required = true,
          icon = 'user', placeholder = 'Given name' },
        { type = 'input', label = 'Password', password = true,
          description = 'The eye toggles visibility.' },
        { type = 'select', label = 'Department', required = true, icon = 'building',
          options = {
              { value = 'lspd', label = 'Los Santos Police' },
              { value = 'bcso', label = "Blaine County Sheriff" },
              { value = 'sahp', label = 'Highway Patrol' },
          } },
        { type = 'multi-select', label = 'Equipment', clearable = true, icon = 'box',
          options = {
              { value = 'radio',  label = 'Radio' },
              { value = 'cuffs',  label = 'Handcuffs' },
              { value = 'vest',   label = 'Vest' },
              { value = 'camera', label = 'Bodycam' },
          } },
        { type = 'number', label = 'Age', min = 18, max = 120, default = 30 },
        { type = 'slider', label = 'Build', default = 50 },
        { type = 'date', label = 'Date of birth', icon = 'cake-candles',
          format = 'DD/MM/YYYY' },
        { type = 'time', label = 'Start of shift', format = '24' },
        { type = 'color', label = 'Livery accent', default = '#22B8E0', format = 'hex' },
        { type = 'textarea', label = 'Notes', autosize = true },
        { type = 'checkbox', label = 'I have read the rules', required = true },
    }, { allowCancel = true })

    print(('uiinput -> %s'):format(json.encode(result or 'cancelled')))
end)

-- ────────────────────────────────────────────────────────────────────
--  Dialogs and menus
-- ────────────────────────────────────────────────────────────────────

preview('alert', 'An alert dialog with two buttons', function()
    local answer = lib.alertDialog({
        header = 'Impound this vehicle?',
        content = 'It will be removed from the street and the owner charged a\n'
            .. 'release fee. **This cannot be undone.**',
        centered = true,
        cancel = true,
        labels = { confirm = 'Impound', cancel = 'Leave it' },
    })
    print(('uialert -> %s'):format(tostring(answer)))
end)

preview('context', 'A context menu, including a submenu', function()
    lib.registerContext({
        id = 'ui_preview_sub',
        title = 'Vehicle Actions',
        menu = 'ui_preview_context',
        options = {
            { title = 'Run the plate', description = 'Check the registry',
              icon = 'magnifying-glass' },
            { title = 'Impound', description = 'Remove it from the street',
              icon = 'truck-ramp-box' },
        },
    })

    lib.registerContext({
        id = 'ui_preview_context',
        title = 'Context Menu',
        options = {
            { title = 'Plain option', description = 'A description sits underneath.' },
            { title = 'With an icon', icon = 'user', description = 'Icons are optional.' },
            { title = 'Opens a submenu', icon = 'car', menu = 'ui_preview_sub',
              description = 'Arrow on the right; the submenu can come back.' },
            { title = 'Disabled', icon = 'ban', disabled = true,
              description = 'Shown, but cannot be chosen.' },
            { title = 'With metadata', icon = 'circle-info',
              metadata = { { label = 'Plate', value = 'LSPD0042' },
                           { label = 'Owner', value = 'J. Doe' } } },
            { title = 'Progress', icon = 'gauge', progress = 65,
              colorScheme = 'amber', description = 'A bar inside the row.' },
        },
    })

    lib.showContext('ui_preview_context')
end)

preview('menu', 'The list menu, arrow keys to move', function()
    -- Rows with and without a description on purpose: the tooltip only
    -- appears for the ones that have it, and moving between them is
    -- exactly what used to shove the menu sideways.
    lib.registerMenu({
        id = 'ui_preview_menu',
        title = 'List Menu',
        position = 'top-right',
        options = {
            { label = 'Plain row', description = 'This row has a description.' },
            { label = 'No description', icon = 'shield' },
            { label = 'Side values', values = { 'Off', 'Low', 'High' }, defaultIndex = 2,
              description = 'Left and right cycle the value.' },
            { label = 'Checkbox row', checked = true },
            { label = 'Close the menu', close = true, icon = 'xmark' },
        },
    }, function(selected, scrollIndex)
        print(('uimenu -> row %s, value %s'):format(selected, scrollIndex))
    end)

    lib.showMenu('ui_preview_menu')
end)

preview('radial', 'The radial menu, with a nested ring', function()
    lib.registerRadial({
        id = 'ui_preview_radial_sub',
        items = {
            { label = 'Cuff',   icon = 'handcuffs' },
            { label = 'Search', icon = 'magnifying-glass' },
            { label = 'Escort', icon = 'hand' },
        },
    })

    lib.addRadialItem({
        { id = 'ui_preview_a', label = 'Person', icon = 'user',
          menu = 'ui_preview_radial_sub' },
        { id = 'ui_preview_b', label = 'Vehicle', icon = 'car',
          onSelect = function() print('uiradial -> vehicle') end },
        { id = 'ui_preview_c', label = 'Radio', icon = 'walkie-talkie',
          onSelect = function() print('uiradial -> radio') end },
        { id = 'ui_preview_d', label = 'Camera', icon = 'camera',
          onSelect = function() print('uiradial -> camera') end },
    })

    -- There is no lib.showRadial: the radial is opened by its own
    -- keybind (`Z` by default, rebindable in the FiveM key settings).
    -- Registering the items is all a preview can do; the notification
    -- says so rather than leaving you pressing a command that appears
    -- to do nothing.
    lib.notify({
        title = 'Radial items registered',
        description = 'Press **Z** to open the radial menu. '
            .. 'They clear themselves in twenty seconds.',
        type = 'info',
        position = 'top-right',
        duration = 7000,
        icon = 'circle-dot',
    })

    -- They take themselves out again. A preview that permanently added
    -- four entries to everyone's radial menu would be a worse bug than
    -- the one it is demonstrating.
    CreateThread(function()
        Wait(20000)
        for _, id in ipairs(RADIAL_PREVIEW_IDS) do
            lib.removeRadialItem(id)
        end
    end)
end)

-- ────────────────────────────────────────────────────────────────────
--  Progress and feedback
-- ────────────────────────────────────────────────────────────────────

preview('progress', 'The progress bar', function()
    if lib.progressBar({
        duration = 5000,
        label = 'Searching the vehicle',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true },
    }) then
        print('uiprogress -> finished')
    else
        print('uiprogress -> cancelled')
    end
end)

preview('circle', 'The circular progress indicator', function()
    if lib.progressCircle({
        duration = 5000,
        label = 'Picking the lock',
        position = 'middle',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true },
    }) then
        print('uicircle -> finished')
    else
        print('uicircle -> cancelled')
    end
end)

preview('skill', 'The skill check, three rounds of increasing difficulty', function()
    local passed = lib.skillCheck({ 'easy', 'medium', 'hard' }, { 'w', 'a', 's', 'd' })
    print(('uiskill -> %s'):format(passed and 'passed' or 'failed'))
end)

preview('textui', 'The text prompt, shown for eight seconds', function()
    lib.showTextUI('[E]  Open the front desk', {
        position = 'right-center',
        icon = 'hand',
    })

    -- It clears itself. The prompt is the one element with no natural
    -- end, and there is no separate hide command any more -- leaving it
    -- stuck on screen would be the preview's fault, not the player's.
    CreateThread(function()
        Wait(8000)
        if lib.isTextUIOpen() then lib.hideTextUI() end
    end)
end)

-- ────────────────────────────────────────────────────────────────────
--  The tour
--
--  Every preview in turn, ten seconds each.
--
--  Two things make this work rather than pile up:
--
--    * each step runs in its OWN thread, because half of these block
--      until the player answers -- an input dialog would otherwise hold
--      the timer open until somebody pressed Confirm, and the tour would
--      stop being a tour;
--
--    * the screen is cleared BEFORE each step and again at the end, so
--      whatever the last one left behind is gone before the next appears
--      rather than stacking on top of it.
-- ────────────────────────────────────────────────────────────────────

local STEP_MS = 10000
local touring = false

RegisterCommand('uiall', function()
    if touring then
        lib.notify({
            title = 'Already running',
            description = 'Use /uistop to end the tour.',
            type = 'warning', position = 'top-right', duration = 4000,
        })
        return
    end

    touring = true

    CreateThread(function()
        local steps = {}
        for _, entry in ipairs(previews) do
            if entry.tour then steps[#steps + 1] = entry end
        end

        lib.notify({
            title = 'UI tour',
            description = ('%d elements, %d seconds each. /uistop to end it.')
                :format(#steps, STEP_MS / 1000),
            type = 'info', position = 'top-right', duration = 5000,
            icon = 'play',
        })
        Wait(2500)

        for index, entry in ipairs(steps) do
            if not touring then break end

            closeEverything()
            Wait(200)

            print(('^3[ui tour]^7 %d/%d  /%s'):format(index, #steps, entry.command))

            -- Its own thread: a blocking preview must not hold the clock.
            CreateThread(entry.fn)

            -- Polled rather than one long Wait, so /uistop takes effect
            -- within a moment instead of at the end of the step.
            local waited = 0
            while touring and waited < STEP_MS do
                Wait(100)
                waited = waited + 100
            end
        end

        closeEverything()

        if touring then
            lib.notify({
                title = 'UI tour finished',
                description = 'Every element has been shown.',
                type = 'success', position = 'top-right', duration = 5000,
                icon = 'check',
            })
        end

        touring = false
    end)
end, false)

RegisterCommand('uistop', function()
    if not touring then
        closeEverything()
        return
    end

    touring = false
    closeEverything()

    lib.notify({
        title = 'UI tour stopped',
        type = 'inform', position = 'top-right', duration = 3000,
    })
end, false)

-- ────────────────────────────────────────────────────────────────────
--  Help
-- ────────────────────────────────────────────────────────────────────

RegisterCommand('uihelp', function()
    print(('^3[ox_lib preview]^7 %d commands:'):format(#previews + 3))

    for _, entry in ipairs(previews) do
        print(('  ^5/%s^7%s%s%s'):format(
            entry.command,
            (' '):rep(math.max(1, 18 - #entry.command)),
            entry.description,
            entry.tour and '' or '   ^8(not in /uiall)^7'))
    end

    print('  ^5/uiall^7             Every element in turn, 10 seconds each')
    print('  ^5/uistop^7            End the tour and clear the screen')
    print('  ^5/uihelp^7            This list')
end, false)

TriggerEvent('chat:addSuggestion', '/uiall', 'Preview every element in turn, 10 seconds each')
TriggerEvent('chat:addSuggestion', '/uistop', 'End the UI tour and clear the screen')
TriggerEvent('chat:addSuggestion', '/uihelp', 'List every ox_lib preview command')
