--[[
    ox_lib / resource/notification_offset.lua

    Where notifications sit on screen, and how far in from the edge.

    ─────────────────────────────────────────────────────────────────────
    This is the only file you need to edit. Change a value, restart
    ox_lib, done -- there is no rebuild needed for anything in here.
]]

return {

    --- Where notifications appear by default.
    ---
    --- One of:
    ---   'top-left'       'top-middle'       'top-right'
    ---   'center-left'                       'center-right'
    ---   'bottom-left'    'bottom-middle'    'bottom-right'
    ---
    --- ('top-middle' / 'bottom-middle' are also accepted as ox_lib's own
    ---  names, 'top' and 'bottom'. Both work.)
    position = 'center-right',

    --- Ignore the player's own choice from the /ox_lib settings menu and
    --- the `position` passed by other scripts, and always use the
    --- position above.
    ---
    --- false  = `position` is the DEFAULT. A script asking for a specific
    ---          corner still gets it, and a player who picked a position
    ---          in /ox_lib keeps theirs.
    --- true   = every notification goes where this file says, no
    ---          exceptions. Note this also overrides scripts that place a
    ---          notification deliberately, so it can look wrong in a UI
    ---          that expects a corner to be free.
    force = true,

    --- How far in from the edge of the screen, in pixels.
    ---
    --- ox_lib ships 18, which sits very tight into the corner on a 1080p
    --- screen and can collide with other HUD elements. 48/32 is a
    --- comfortable starting point.
    ---
    --- `x` is the gap from the left or right edge -- it does nothing for
    --- the two middle positions, which are horizontally centred.
    --- `y` is the gap from the top or bottom edge -- it does nothing for
    --- the two center positions, which are vertically centred.
    offset = {
        x = 48,
        y = 32,
    },

    --- Optional per-position overrides, for when one corner needs to
    --- clear a HUD element the others do not. Anything not listed here
    --- falls back to `offset` above.
    ---
    --- Example: push only the top-right down past a minimap or a
    --- speedometer, and leave every other position alone.
    ---
    ---     overrides = {
    ---         ['top-right'] = { x = 48, y = 180 },
    ---     },
    overrides = {
        -- ['top-right']    = { x = 48, y = 32 },
        -- ['bottom-right'] = { x = 48, y = 220 },
    },
}
