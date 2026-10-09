-- ------------------------------------------------------------------
--  ox_lib UI colours (tampilan redesign, dari ox_lib backup)
--  Disalin oleh ox_lib_f_patch/apply.ps1 ke resource/colors/client.lua
--
--  `primary` menggerakkan seluruh warna aksen. Latar notifikasi memakai
--  var(--f-notify-bg) supaya transparan saat blur kaca aktif (f_theme.css).
-- ------------------------------------------------------------------

local ACCENT      = '#F3B354'
local ACCENT_RGB  = '243, 179, 84'
local NOTIFY_BG   = 'var(--f-notify-bg)'

lib.uiColors = {
    primary = ACCENT,

    progress = {
        color = ACCENT,
        glow = ('rgba(%s, 0.30)'):format(ACCENT_RGB),
    },

    textUI = {
        border = ACCENT,
    },

    -- Notifikasi tetap semantik (hijau/merah/kuning), tidak ikut aksen.
    notifications = {
        success = { border = 'rgba(255, 255, 255, 0.08)', title = '#5BD6A0', corners = '#5BD6A0', background = NOTIFY_BG },
        error   = { border = 'rgba(255, 255, 255, 0.08)', title = '#F0625B', corners = '#F0625B', background = NOTIFY_BG },
        warning = { border = 'rgba(255, 255, 255, 0.08)', title = '#FFC048', corners = '#FFC048', background = NOTIFY_BG },
        inform  = { border = 'rgba(255, 255, 255, 0.08)', title = '#8FA3AD', corners = '#C2D2DA', background = NOTIFY_BG },
    },

    input = {
        focusBorder = ACCENT,
        focusGlow = ('rgba(%s, 0.26)'):format(ACCENT_RGB),
        focusBackground = 'rgba(255, 255, 255, 0.06)',
        activeLabel = ACCENT,
        confirmButton = ACCENT,
        confirmButtonHover = '#FFC878',
        cancelButton = 'rgba(255, 255, 255, 0.035)',
        cancelButtonHover = 'rgba(255, 255, 255, 0.08)',
    },

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

    radial = {
        activeSegment = ACCENT,
        indicator = ACCENT,
    },

    skillCheck = {
        success = ACCENT,
    },
}
