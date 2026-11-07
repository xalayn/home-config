-- Hyprland config (Lua, Hyprland 0.57)
-- Programs and keybinds match the niri setup; colors follow niri's
-- mauve -> teal focus ring.
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- Validate with: Hyprland --verify-config

local configDir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"


----------------
---- THEME  ----
----------------

-- One place for every color, so the borders, glow and groups stay in step.
local theme = {
    mauve    = "dc8af1",
    teal     = "0fa0a0",
    peach    = "ffc87f",
    red      = "f38ba8",
    base     = "11111b",
    surface  = "313244",
    text     = "cdd6f4",
}

local function rgba(hex, alpha)
    return "rgba(" .. hex .. (alpha or "ff") .. ")"
end


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "wezterm"
local fileManager = "thunar"
local menu        = "fuzzel"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
-- (mako is started by its home-manager systemd service, so it's not here)
hl.on("hyprland.start", function ()
    hl.exec_cmd("waybar")
    hl.exec_cmd("waypaper --restore")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "32")
hl.env("HYPRCURSOR_SIZE", "32")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = 14,

        border_size = 2,

        col = {
            active_border   = { colors = { rgba(theme.mauve, "ee"), rgba(theme.teal, "ee") }, angle = 45 },
            inactive_border = rgba(theme.surface, "aa"),
        },

        -- Resize windows by clicking and dragging on borders and gaps
        resize_on_border        = true,
        extend_border_grab_area = 12,
        hover_icon_on_border    = true,

        -- Floating windows snap to each other and to the screen edges
        snap = {
            enabled       = true,
            window_gap    = 12,
            monitor_gap   = 14,
            respect_gaps  = true,
        },

        allow_tearing = false,

        -- niri-style: each workspace is an endless horizontal strip of columns
        layout = "scrolling",
    },

    decoration = {
        rounding       = 14,
        rounding_power = 3,       -- a little squircle, softer than a circle arc

        active_opacity     = 1.0,
        inactive_opacity   = 0.96,
        fullscreen_opacity = 1.0,

        -- Gently dim unfocused windows so the active one stands out
        dim_inactive = true,
        dim_strength = 0.06,
        dim_special  = 0.35,      -- dims what's behind the scratchpad

        shadow = {
            enabled        = true,
            range          = 22,
            render_power   = 3,
            offset         = { 0, 6 },
            color          = "rgba(0000005c)",
            color_inactive = "rgba(00000033)",
        },

        -- A faint halo in the accent color around the focused window
        glow = {
            enabled        = true,
            range          = 10,
            render_power   = 3,
            color          = rgba(theme.mauve, "33"),
            color_inactive = "rgba(00000000)",
        },

        blur = {
            enabled           = true,
            size              = 7,
            passes            = 2,     -- niri: passes 2
            noise             = 0.015,
            contrast          = 0.95,
            brightness        = 0.85,
            vibrancy          = 0.2,
            vibrancy_darkness = 0.4,
            popups            = true,
            special           = true,
            new_optimizations = true,
            -- niri: xray true. Windows show the blurred wallpaper (computed once)
            -- instead of re-blurring whatever is behind each one every frame,
            -- which is what kept the overview zoom from hitting full frame rate.
            xray              = true,
        },
    },

    group = {
        col = {
            border_active   = { colors = { rgba(theme.peach, "ee"), rgba(theme.mauve, "ee") }, angle = 45 },
            border_inactive = rgba(theme.surface, "aa"),
        },
        groupbar = {
            font_size    = 11,
            height       = 18,
            rounding     = 6,
            gradients    = true,
            text_color   = rgba(theme.base),
            col = {
                active   = rgba(theme.mauve, "dd"),
                inactive = rgba(theme.surface, "aa"),
            },
        },
    },

    animations = {
        enabled = true,
    },
})

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
-- Timed to match niri's defaults. Springs ignore `speed`: their length comes
-- from stiffness alone. niri uses critically damped springs (damping ratio 1,
-- so dampening = 2 * sqrt(stiffness)) that settle in about 0.2 s.
-- Beziers take `speed` in tenths of a second.
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeOutExpo",    { type = "bezier", points = { {0.16, 1},    {0.3, 1}     } })
hl.curve("easeOutQuad",    { type = "bezier", points = { {0.5, 1},     {0.89, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("niriWorkspace",  { type = "spring", mass = 1, stiffness = 1000, dampening = 63 })
hl.curve("niriMove",       { type = "spring", mass = 1, stiffness = 800,  dampening = 57 })

hl.animation({ leaf = "global",        enabled = true,  speed = 2,    bezier = "easeOutQuint" })
hl.animation({ leaf = "border",        enabled = true,  speed = 1.5,  bezier = "easeOutQuint" })
hl.animation({ leaf = "borderangle",   enabled = true,  speed = 60,   bezier = "linear",       style = "loop" })
-- niri window-movement / horizontal-view-movement / window-resize
hl.animation({ leaf = "windows",       enabled = true,  speed = 2,    spring = "niriMove" })
hl.animation({ leaf = "windowsMove",   enabled = true,  speed = 2,    spring = "niriMove" })
-- niri window-open: 150 ms linear (your config); window-close: 150 ms ease-out-quad
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "popin 85%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.5,  bezier = "easeOutQuad",  style = "popin 85%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.5,  bezier = "linear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.5,  bezier = "easeOutQuad" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 1.5,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeDim",       enabled = true,  speed = 1.5,  bezier = "easeOutQuint" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 1.5,  bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 1.5,  bezier = "easeOutExpo",  style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "easeOutQuad",  style = "fade" })
-- niri workspace-switch; workspaces stack vertically
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 2,    spring = "niriWorkspace", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2,  spring = "niriWorkspace", style = "slidevert" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 2,    bezier = "easeOutQuint" })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/
hl.config({
    dwindle = {
        preserve_split = true,
        smart_split    = false,
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- Mirrors niri's layout {} block.
hl.config({
    scrolling = {
        column_width             = 0.5,                  -- default-column-width 0.5
        explicit_column_widths   = "0.333, 0.5, 0.667",  -- preset-column-widths (Mod+R)
        focus_fit_method         = 1,     -- scroll just enough to show the focused column
                                          -- (closest to center-focused-column "on-overflow")
        follow_focus             = true,
        wrap_focus               = false, -- niri doesn't wrap around at the ends
        wrap_swapcol             = false,
        fullscreen_on_one_column = false, -- a lone column keeps its width, like niri
    },
})


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper  = 0,    -- waypaper handles the wallpaper
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = rgba(theme.base),
        animate_manual_resizes   = true,
        animate_mouse_windowdragging = false, -- dragging should feel 1:1
        focus_on_activate        = true,
        key_press_enables_dpms   = true,  -- any key wakes monitors after Mod+Shift+P
        mouse_move_enables_dpms  = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        numlock_by_default = true,        -- niri: numlock

        -- niri doesn't focus on hover: the window under the pointer gets
        -- mouse input, keyboard focus moves on click.
        follow_mouse = 2,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            tap_to_click   = true,        -- niri: tap
            natural_scroll = true,        -- niri: natural-scroll
        },
    },

    -- niri doesn't warp the pointer to the focused window
    cursor = {
        no_warps = true,
    },

    -- niri: cooldown-ms=150 on the Mod+wheel workspace binds
    binds = {
        scroll_event_delay = 150,
    },
})

-- Touchpad gestures, as in niri:
--   3 fingers left/right scrolls the strip of columns
--   3 fingers up/down switches workspaces
--   4 fingers up/down opens the overview (see SCROLLOVERVIEW below)
hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
-- (the vertical swipes are set up next to the workspace binds below)


---------------------
---- KEYBINDINGS ----
---------------------

-- A 1:1 translation of the binds {} block in the niri config
-- (home-config/modules/alex-desktop/niri/dotfiles/config.kdl), using the
-- scrolling layout's messages for niri's column actions.
-- See https://wiki.hypr.land/Configuring/Basics/Binds/

local mainMod = "SUPER"

local function exec(cmd)  return hl.dsp.exec_cmd(cmd) end
local function msg(m)     return hl.dsp.layout(m) end   -- scrolling layout message

-- Run a layout message repeatedly. At the first/last column "focus" and
-- "swapcol" stop moving (wrapping is off), so this lands on the end.
local function toEnd(m)
    return function()
        for _ = 1, 50 do hl.dispatch(hl.dsp.layout(m)) end
    end
end

---- Programs ----
hl.bind(mainMod .. " + T",         exec(terminal))
hl.bind(mainMod .. " + ALT + T",   exec("cool-retro-term"))
hl.bind(mainMod .. " + D",         exec(menu))
hl.bind(mainMod .. " + E",         exec(fileManager .. " -w"))
hl.bind(mainMod .. " + ALT + L",   exec("swaylock"))
hl.bind(mainMod .. " + ALT + P",   exec("wlogout"))
hl.bind(mainMod .. " + CTRL + H",  exec("systemctl hibernate"))
hl.bind(mainMod .. " + SHIFT + C", exec("wl-color-picker"))
hl.bind(mainMod .. " + M",         exec("xdotool key Alt_R"))
hl.bind(mainMod .. " + Space",     exec("xdotool key Alt_R"))

---- Volume (niri: 10% steps, work on the lock screen) ----
hl.bind("XF86AudioRaiseVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"),          { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"),          { locked = true, repeating = true })
hl.bind("XF86AudioMute",        exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),          { locked = true })
hl.bind("XF86AudioMicMute",     exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),        { locked = true })

---- Overview: Mod+O / Mod+Tab (bound in SCROLLOVERVIEW below) ----

---- Windows ----
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

-- Focus: left/right between columns, up/down within a column
-- Move:  Ctrl + left/right moves the column, Ctrl + up/down the window
--        (no Mod+Ctrl+H: that's hibernate, as in niri)
local directions = {
    { keys = { "left",  "H" }, focus = "focus l", move = msg("swapcol l") },
    { keys = { "right", "L" }, focus = "focus r", move = msg("swapcol r") },
    { keys = { "up",    "K" }, focus = "focus u", move = hl.dsp.window.move({ direction = "up" }) },
    { keys = { "down",  "J" }, focus = "focus d", move = hl.dsp.window.move({ direction = "down" }) },
}
for _, d in ipairs(directions) do
    for _, key in ipairs(d.keys) do
        hl.bind(mainMod .. " + " .. key, msg(d.focus))
        if key ~= "H" then
            hl.bind(mainMod .. " + CTRL + " .. key, d.move)
        end
    end
end

-- First / last column
hl.bind(mainMod .. " + Home",        toEnd("focus l"))
hl.bind(mainMod .. " + End",         toEnd("focus r"))
hl.bind(mainMod .. " + CTRL + Home", toEnd("swapcol l"))
hl.bind(mainMod .. " + CTRL + End",  toEnd("swapcol r"))

---- Monitors: Shift focuses, Shift+Ctrl moves the window there ----
local monitorDirs = {
    left = "l", right = "r", up = "u", down = "d",
    H = "l", L = "r", K = "u", J = "d",
}
for key, dir in pairs(monitorDirs) do
    hl.bind(mainMod .. " + SHIFT + " .. key,        hl.dsp.focus({ monitor = dir }))
    hl.bind(mainMod .. " + SHIFT + CTRL + " .. key, hl.dsp.window.move({ monitor = dir }))
end

---- Workspaces: niri's dynamic, per-monitor vertical stack ----
-- Each monitor has its own ordered column of workspaces with an empty one
-- below the last (and, like niri's empty-workspace-above-first, an empty one
-- above the first). Hyprland workspace ids are global, so the order on a
-- monitor is just its workspaces sorted by id; ids are never shown anywhere.
-- Hyprland already removes empty workspaces you leave, like niri does.

local function isNormal(ws)
    return ws and not ws.special and ws.id > 0
end

-- This monitor's workspaces, top to bottom, as a list of slots
-- { id = n } plus { above = true } / { below = true } for the empty ends.
local function workspaceStack()
    local mon  = hl.get_active_monitor()
    local cur  = mon.active_workspace
    local list = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if isNormal(ws) and ws.monitor.name == mon.name then
            list[#list + 1] = { id = ws.id, windows = ws.windows }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)

    local slots = {}
    if #list > 0 and list[1].windows > 0 then slots[1] = { above = true } end
    for _, ws in ipairs(list) do slots[#slots + 1] = ws end
    if #list > 0 and list[#list].windows > 0 then slots[#slots + 1] = { below = true } end

    local index = 1
    for i, s in ipairs(slots) do
        if isNormal(cur) and s.id == cur.id then index = i end
    end
    return slots, index, list, mon
end

local function usedIds()
    local used = {}
    for _, ws in ipairs(hl.get_workspaces()) do used[ws.id] = ws end
    return used
end

-- Turn a slot into a real workspace id, making room above the first
-- workspace when needed by renumbering this monitor's workspaces
-- (change_id keeps their windows and columns as they are).
local function slotId(slot, list, mon)
    if slot.id then return slot.id end
    local used = usedIds()
    if slot.below then
        local id = list[#list].id + 1
        while used[id] do id = id + 1 end
        return id
    end
    -- above: any free id below the first one will do
    for id = list[1].id - 1, 1, -1 do
        if not used[id] then return id end
    end
    -- none free: shift this monitor's workspaces down the id range
    local shift = 1
    local function clash(id)
        return used[id] and used[id].monitor.name ~= mon.name
    end
    while true do
        local ok = true
        for _, ws in ipairs(list) do
            if clash(ws.id + shift) then ok = false; break end
        end
        if ok then break end
        shift = shift + 1
    end
    for i = #list, 1, -1 do
        hl.dispatch(hl.dsp.workspace.change_id({ workspace = list[i].id, id = list[i].id + shift }))
    end
    used = usedIds()
    for id = list[1].id + shift - 1, 1, -1 do
        if not used[id] then return id end
    end
end

-- Go to (or, with move = true, take the focused window to) the workspace
-- `delta` steps up/down the stack, or the n-th one from the top (`nth`).
local function workspaceGo(opts)
    return function()
        local slots, index, list, mon = workspaceStack()
        if #slots == 0 then return end
        local target
        if opts.nth then
            target = math.min(opts.nth, #slots)
        else
            target = index + opts.delta
        end
        if target < 1 or target > #slots or target == index then return end
        if opts.move and not hl.get_active_window() then return end

        local id = slotId(slots[target], list, mon)
        if not id then return end
        if opts.move then
            hl.dispatch(hl.dsp.window.move({ workspace = id }))
        else
            hl.dispatch(hl.dsp.focus({ workspace = id }))
        end
    end
end

for _, key in ipairs({ "Page_Down", "U" }) do
    hl.bind(mainMod .. " + " .. key,        workspaceGo({ delta = 1 }))
    hl.bind(mainMod .. " + CTRL + " .. key, workspaceGo({ delta = 1, move = true }))
end
for _, key in ipairs({ "Page_Up", "I" }) do
    hl.bind(mainMod .. " + " .. key,        workspaceGo({ delta = -1 }))
    hl.bind(mainMod .. " + CTRL + " .. key, workspaceGo({ delta = -1, move = true }))
end

-- Mod + 1…9: the n-th workspace on this monitor, counted from the top as
-- niri does (so with the empty one above, Mod+1 is that empty one).
-- Mod + Ctrl + 1…9 takes the window there.
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,        workspaceGo({ nth = i }))
    hl.bind(mainMod .. " + CTRL + " .. i, workspaceGo({ nth = i, move = true }))
end

-- Keep every monitor's workspace ids contiguous in a range of its own
-- (monitor 0: 1001, 1002, …; monitor 1: 2001, …), with the id just above the
-- first and just below the last always free. Then "the id ±1" is exactly
-- niri's neighbour, and Hyprland's own 1:1 touchpad swipe (set to use ids,
-- see workspace_swipe_use_r below) can follow your fingers onto a new empty
-- workspace above the first or below the last.
-- Runs just after any workspace change, never in the middle of one.
local tidyPending = false
local function tidyWorkspaceIds()
    tidyPending = false
    local byMonitor, monitorIds = {}, {}
    for _, mon in ipairs(hl.get_monitors()) do monitorIds[mon.name] = mon.id end
    for _, ws in ipairs(hl.get_workspaces()) do
        if isNormal(ws) and monitorIds[ws.monitor.name] then
            local name = ws.monitor.name
            byMonitor[name] = byMonitor[name] or {}
            table.insert(byMonitor[name], ws.id)
        end
    end

    local moves = {}
    for name, ids in pairs(byMonitor) do
        table.sort(ids)
        local base = 1000 * (monitorIds[name] + 1)
        for i, id in ipairs(ids) do
            if id ~= base + i then moves[#moves + 1] = { from = id, to = base + i } end
        end
    end
    if #moves == 0 then return end

    -- Two steps via spare ids, so no move lands on an id still in use
    for i, m in ipairs(moves) do
        hl.dispatch(hl.dsp.workspace.change_id({ workspace = m.from, id = 900000 + i }))
    end
    for i, m in ipairs(moves) do
        hl.dispatch(hl.dsp.workspace.change_id({ workspace = 900000 + i, id = m.to }))
    end
end

local function scheduleTidy()
    if tidyPending then return end
    tidyPending = true
    hl.timer(tidyWorkspaceIds, { timeout = 1, type = "oneshot" })
end

for _, event in ipairs({ "workspace.active", "workspace.created", "workspace.removed",
                         "workspace.move_to_monitor", "monitor.added", "monitor.removed",
                         "hyprland.start" }) do
    hl.on(event, scheduleTidy)
end

-- 3 fingers up/down: workspace swipe that follows your fingers. Registered in
-- the SCROLLOVERVIEW section below, so that with the plugin it also works
-- inside the overview.
hl.config({
    gestures = {
        workspace_swipe_use_r      = true, -- neighbours are id ± 1 (see above)
        workspace_swipe_create_new = true, -- swiping past either end makes an empty one
        workspace_swipe_forever    = true, -- one long swipe can pass several workspaces, like niri
    },
})

---- Mouse wheel ----
-- Mod + wheel: workspaces;  Mod + Shift + wheel / horizontal wheel: columns
hl.bind(mainMod .. " + mouse_down",                workspaceGo({ delta = 1 }))
hl.bind(mainMod .. " + mouse_up",                  workspaceGo({ delta = -1 }))
hl.bind(mainMod .. " + CTRL + mouse_down",         workspaceGo({ delta = 1, move = true }))
hl.bind(mainMod .. " + CTRL + mouse_up",           workspaceGo({ delta = -1, move = true }))
hl.bind(mainMod .. " + mouse_right",               msg("focus r"))
hl.bind(mainMod .. " + mouse_left",                msg("focus l"))
hl.bind(mainMod .. " + CTRL + mouse_right",        msg("swapcol r"))
hl.bind(mainMod .. " + CTRL + mouse_left",         msg("swapcol l"))
hl.bind(mainMod .. " + SHIFT + mouse_down",        msg("focus r"))
hl.bind(mainMod .. " + SHIFT + mouse_up",          msg("focus l"))
hl.bind(mainMod .. " + CTRL + SHIFT + mouse_down", msg("swapcol r"))
hl.bind(mainMod .. " + CTRL + SHIFT + mouse_up",   msg("swapcol l"))

-- Mod + drag moves a window, Mod + right-drag resizes it
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

---- Columns ----
hl.bind(mainMod .. " + bracketleft",  msg("consume_or_expel prev"))
hl.bind(mainMod .. " + bracketright", msg("consume_or_expel next"))
hl.bind(mainMod .. " + comma",        msg("consume"))   -- pull the next column's window in
hl.bind(mainMod .. " + period",       msg("expel"))     -- push a window out into its own column

hl.bind(mainMod .. " + R",            msg("colresize +conf"))  -- cycle preset widths
hl.bind(mainMod .. " + minus",        msg("colresize -0.1"))
hl.bind(mainMod .. " + equal",        msg("colresize +0.1"))
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -80, relative = true }))
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y =  80, relative = true }))

hl.bind(mainMod .. " + F",            hl.dsp.window.fullscreen({ mode = "maximized" })) -- maximize-column
hl.bind(mainMod .. " + SHIFT + F",    hl.dsp.window.fullscreen())                       -- fullscreen-window
hl.bind(mainMod .. " + CTRL + F",     msg("fit expand"))   -- expand-column-to-available-width
hl.bind(mainMod .. " + C",            msg("center"))       -- center-column
hl.bind(mainMod .. " + CTRL + C",     msg("fit visible"))  -- center-visible-columns

hl.bind(mainMod .. " + W",            hl.dsp.group.toggle()) -- tabbed column (as a Hyprland group)

---- Floating ----
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- Switch focus between floating and tiled windows
hl.bind(mainMod .. " + SHIFT + V", function()
    local ok, active = pcall(hl.get_window, "activewindow")
    if ok and active and active.floating then
        hl.dispatch(hl.dsp.window.cycle_next({ tiled = true }))
    else
        hl.dispatch(hl.dsp.window.cycle_next({ floating = true }))
    end
end)

---- Screenshots, saved where niri saves them and copied to the clipboard ----
local function screenshot(geometry)
    return exec(
        'dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"; ' ..
        'f="$dir/Screenshot from $(date "+%Y-%m-%d %H-%M-%S").png"; ' ..
        'grim ' .. (geometry and ('-g "' .. geometry .. '" ') or '') .. '"$f" && wl-copy < "$f"')
end
hl.bind("Print",        screenshot("$(slurp -d -b 11111b88 -c dc8af1ff -w 2)")) -- pick a region
hl.bind("CTRL + Print", screenshot(nil))                                         -- whole screen
hl.bind("ALT + Print",  screenshot("$(hyprctl activewindow -j | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"')")) -- focused window

---- Session ----
local quit = exec("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
hl.bind(mainMod .. " + SHIFT + E", quit)
hl.bind("CTRL + ALT + Delete",     quit)
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.dpms({ action = "off" })) -- power off monitors; any key wakes them

---- Not in niri's binds, kept so the laptop keys keep working ----
hl.bind("XF86MonBrightnessUp",  exec("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",exec("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Media keys (requires playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

hl.window_rule({
    -- Ignore maximize requests from all apps
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    -- Small utility windows float, centered
    name  = "float-utilities",
    match = { class = "^(org\\.pulseaudio\\.pavucontrol|blueberry\\.py|nm-connection-editor|xdg-desktop-portal-gtk|org\\.gnome\\.Calculator)$" },

    float  = true,
    center = true,
})

hl.window_rule({
    -- Picture-in-Picture stays on top in a corner
    name  = "pip",
    match = { title = "^Picture-in-Picture$" },

    float = true,
    pin   = true,
})

-- Frosted glass behind the launcher, notifications and bar
-- (only visible where they draw with a translucent background)
hl.layer_rule({
    name         = "blur-shell",
    match        = { namespace = "^(launcher|notifications|waybar)$" },
    blur         = true,
    ignore_alpha = 0.2,
})


------------------------
---- SCROLLOVERVIEW ----
------------------------

-- Niri-like overview of all workspaces, built by home-manager
-- (alex-desktop.hyprland.scrolloverview). scrolloverview-plugin.lua holds the
-- Nix store path of the build; it is absent when the plugin is disabled.
-- Wiki: https://github.com/yayuuu/hyprland-scroll-overview/wiki
local ok, pluginPath = pcall(dofile, configDir .. "/scrolloverview-plugin.lua")
if ok and type(pluginPath) == "string" then
    hl.plugin.load(pluginPath)
end

-- Hyprland parses the config again once the plugin is in; until then (or
-- without the plugin) none of this applies.
local function scrolloverviewLoaded()
    for _, plugin in ipairs(hl.get_loaded_plugins()) do
        if plugin.name == "scrolloverview" then
            return true
        end
    end
    return false
end

if scrolloverviewLoaded() then
    hl.config({
        plugin = {
            scrolloverview = {
                scale            = 0.5,        -- how far the overview zooms out
                workspace_gap    = 60,
                layout           = "vertical", -- workspaces stacked like niri
                gesture_distance = 300,
                wallpaper        = 2,          -- wallpaper behind and on each workspace
                blur             = true,
                shadow = {
                    enabled = true,
                    range   = 40,
                },
            },
        },
    })

    -- Same keys as niri's overview
    local function toggleOverview()
        hl.plugin.scrolloverview.overview("toggle all")
    end
    hl.bind(mainMod .. " + O",   toggleOverview)
    hl.bind(mainMod .. " + TAB", toggleOverview)

    -- Four-finger swipe up/down opens and closes it, as in niri
    hl.plugin.scrolloverview.gesture({ fingers = 4, direction = "vertical" })

    -- 3 fingers up/down: workspace swipe (patched in, see scrolloverview.nix).
    -- Inside the overview it scrolls the workspaces under your fingers; outside
    -- it is exactly Hyprland's own swipe.
    hl.plugin.scrolloverview.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
else
    hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
end
