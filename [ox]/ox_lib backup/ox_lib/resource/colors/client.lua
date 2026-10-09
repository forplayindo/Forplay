-- ------------------------------------------------------------------
--  ox_lib UI colours
--
--  Cyan-blue system on near-black glass.
--
--  `primary` is the one that matters. Everything the interface tints --
--  chip fills, hover washes, glows, the Mantine palette behind the
--  select and multi-select -- is derived from it, so changing this one
--  value moves the whole interface rather than half of it.
--
--  The per-component entries below exist for the cases where you want
--  something OFF the accent: a red error rail, a green success title.
--  Leave them on the accent unless you mean to break away from it.
-- ------------------------------------------------------------------

--- The accent. Everything else derives from this unless overridden.
local ACCENT      = '#F3B354'  -- cyan-blue
local ACCENT_RGB  = '243, 179, 84'

lib.uiColors = {
    -- Global primary accent. Drives every derived tint.
    primary = ACCENT,

    -- Progress bars (linear & circle)
    progress = {
        color = ACCENT,
        glow = ('rgba(%s, 0.30)'):format(ACCENT_RGB),
    },

    -- TextUI
    textUI = {
        border = ACCENT,
    },

    -- Notifications
    --
    -- These stay SEMANTIC rather than following the accent: a warning
    -- that is the same colour as everything else is not a warning.
    notifications = {
        success = {
            border = 'rgba(255, 255, 255, 0.08)',
            title = '#5BD6A0',
            corners = '#5BD6A0',
            background = 'rgba(14, 17, 20, 0.90)',
        },
        error = {
            border = 'rgba(255, 255, 255, 0.08)',
            title = '#F0625B',
            corners = '#F0625B',
            background = 'rgba(14, 17, 20, 0.90)',
        },
        warning = {
            border = 'rgba(255, 255, 255, 0.08)',
            title = '#FFC048',
            corners = '#FFC048',
            background = 'rgba(14, 17, 20, 0.90)',
        },
        inform = {
            border = 'rgba(255, 255, 255, 0.08)',
            title = '#8FA3AD',
            corners = '#C2D2DA',
            background = 'rgba(14, 17, 20, 0.90)',
        },
    },

    -- Input dialogs
    input = {
        focusBorder = ACCENT,
        focusGlow = ('rgba(%s, 0.26)'):format(ACCENT_RGB),
        focusBackground = 'rgba(255, 255, 255, 0.06)',
        activeLabel = ACCENT,
        confirmButton = ACCENT,
        confirmButtonHover = '#48CCEE',
        cancelButton = 'rgba(255, 255, 255, 0.035)',
        cancelButtonHover = 'rgba(255, 255, 255, 0.08)',
    },

    -- List menu
    list = {
        activeBorder = ACCENT,
        activeBackground = 'rgba(255, 255, 255, 0.06)',
        activeHoverBackground = 'rgba(255, 255, 255, 0.09)',
        iconHoverBackground = ('rgba(%s, 0.14)'):format(ACCENT_RGB),
        iconHoverColor = ACCENT,
        subLabelActive = ACCENT,
        checkboxStroke = ACCENT,
        checkboxFill = ('rgba(%s, 0.18)'):format(ACCENT_RGB),
    },

    -- Radial menu
    radial = {
        activeSegment = ACCENT,
        indicator = ACCENT,
    },

    -- Skill check
    skillCheck = {
        success = ACCENT,
    },
}
