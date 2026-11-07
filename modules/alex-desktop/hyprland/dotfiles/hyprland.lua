-- Hyprland config (Lua, Hyprland 0.57)
-- Programs and keybinds match the niri setup. The look is Frutiger Aero (sky
-- blue glass), Hyprland-only: niri keeps its own look.
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- Validate with: Hyprland --verify-config

local configDir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"


----------------
---- THEME  ----
----------------

-- Frutiger Aero: sky blue, aqua and leaf green over frosted white glass.
-- One place for every color, so the borders, glow and groups stay in step.
local theme = {
    sky      = "4fc3f7",
    aqua     = "5ee6d8",
    leaf     = "8bd448",
    glass    = "ffffff",
    deep     = "0b2a45",   -- deep sea blue, behind everything
    shade    = "0a3a66",   -- blue-tinted shadows
    red      = "f38ba8",
}

local function rgba(hex, alpha)
    return "rgba(" .. hex .. (alpha or "ff") .. ")"
end


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Same layout and scales as niri: laptop panel on the left at scale 1, the
-- HDMI monitor to its right at 1.25. ("auto" scale picked 1.5 for both, which
-- made everything, the cursor included, too big.)
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "0x0",
    scale    = "1",
})
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",
    position = "1920x0",
    scale    = "1.25",
})
-- anything else that gets plugged in
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
-- the Aero-styled launcher config is Hyprland-only (fuzzel/aero.ini)
local menu        = "fuzzel --config " .. (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/fuzzel/aero.ini"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
-- (mako is started by its home-manager systemd service, so it's not here)
hl.on("hyprland.start", function ()
    -- Tell the (shared) user services this is a Hyprland session, then restart
    -- the portal so it picks xdg-desktop-portal-hyprland (screen sharing,
    -- Discord's picker) instead of whatever the previous session left behind.
    hl.exec_cmd("sh -c '"
        .. "dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE"
        .. " XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_DESKTOP=Hyprland XDG_SESSION_TYPE=wayland;"
        .. " systemctl --user unset-environment NIRI_SOCKET;"
        .. " systemctl --user start hyprland-session.target;"
        .. " systemctl --user restart xdg-desktop-portal.service'")
    -- the bar with the Aero style and the current workspace (Hyprland-only;
    -- niri keeps config + style.css)
    local waybarDir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/waybar"
    hl.exec_cmd("waybar -c " .. waybarDir .. "/aero-config.jsonc -s " .. waybarDir .. "/aero.css")
    -- Aero notifications while Hyprland runs (mako is shared with niri): a
    -- small watcher turns the mode back off once this Hyprland has exited
    hl.exec_cmd("systemd-run --user --collect sh -c '"
        .. "makoctl mode -a aero; "
        .. "while [ -S \"$XDG_RUNTIME_DIR/hypr/" .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "") .. "/.socket.sock\" ]; do sleep 5; done; "
        .. "makoctl mode -r aero'")
    hl.exec_cmd("pypr") -- scratchpads, see SCRATCHPADS below
    hl.exec_cmd("waypaper --restore")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
-- Render on the RTX 4050, keeping the Intel GPU (which drives the laptop panel)
-- as the second device. The names come from udev rules in system-config
-- (hosts/alex-laptop); without them Hyprland picks the GPU itself (Intel).
-- The Intel iGPU is too weak for the overview's zoom at 165 Hz.
local function exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end
if exists("/dev/dri/nvidia-dgpu") and exists("/dev/dri/intel-igpu") then
    hl.env("AQ_DRM_DEVICES", "/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu")
end

-- a clean white cursor to go with the Aero look (Hyprland-only)
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "32")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "32")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = 14,

        border_size = 0,   -- no borders; the focused window keeps its aqua glow

        col = {
            active_border   = { colors = { rgba(theme.sky, "ee"), rgba(theme.aqua, "ee"), rgba(theme.leaf, "ee") }, angle = 45 },
            inactive_border = rgba(theme.glass, "44"),   -- a thin frosted edge
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
        rounding       = 16,      -- soft, bubbly corners
        rounding_power = 3,       -- a little squircle, softer than a circle arc

        -- windows are fully opaque
        active_opacity     = 1.0,
        inactive_opacity   = 1.0,
        fullscreen_opacity = 1.0,

        -- no darkening: Aero is bright
        dim_inactive = false,
        dim_strength = 0.06,
        dim_special  = 0.35,      -- dims what's behind the scratchpad

        shadow = {
            enabled        = true,
            range          = 30,
            render_power   = 3,
            offset         = { 0, 8 },
            color          = rgba(theme.shade, "66"),   -- soft blue shadows
            color_inactive = rgba(theme.shade, "33"),
        },

        -- An aqua halo around the focused window
        glow = {
            enabled        = true,
            range          = 14,
            render_power   = 3,
            color          = rgba(theme.aqua, "55"),
            color_inactive = "rgba(00000000)",
        },

        blur = {
            enabled           = true,
            -- frosted glass: bright and saturated rather than dark
            size              = 8,
            passes            = 3,
            noise             = 0.02,
            contrast          = 1.0,
            brightness        = 1.05,
            vibrancy          = 0.35,
            vibrancy_darkness = 0.2,
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
            border_active   = { colors = { rgba(theme.aqua, "ee"), rgba(theme.leaf, "ee") }, angle = 45 },
            border_inactive = rgba(theme.glass, "44"),
        },
        groupbar = {
            font_size    = 11,
            height       = 18,
            rounding     = 6,
            gradients    = true,
            text_color   = rgba(theme.deep),
            col = {
                active   = rgba(theme.sky, "dd"),
                inactive = rgba(theme.glass, "66"),
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
-- focus changes are instant: no fading of opacity, glow/border colour or
-- shadows when switching windows
hl.animation({ leaf = "border",        enabled = false, speed = 1.5,  bezier = "easeOutQuint" })
-- borders stay still (no rotating gradient)
hl.animation({ leaf = "borderangle",   enabled = false, speed = 60,   bezier = "linear" })
-- niri window-movement / horizontal-view-movement / window-resize
hl.animation({ leaf = "windows",       enabled = true,  speed = 2,    spring = "niriMove" })
hl.animation({ leaf = "windowsMove",   enabled = true,  speed = 2,    spring = "niriMove" })
-- niri window-open: 150 ms linear (your config); window-close: 150 ms ease-out-quad
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "popin 85%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.5,  bezier = "easeOutQuad",  style = "popin 85%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.5,  bezier = "linear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.5,  bezier = "easeOutQuad" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 1.5,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeDim",       enabled = false, speed = 1.5,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeSwitch",    enabled = false, speed = 1.5,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeShadow",    enabled = false, speed = 1.5,  bezier = "easeOutQuint" })
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
        background_color         = rgba(theme.deep),
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
-- (3 fingers left/right is set up in EDGE WORKSPACES at the end: niri-style)
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
        workspace_swipe_create_new = true, -- without the edgeworkspaces plugin: swiping past either end makes an empty one
        workspace_swipe_forever    = true, -- one long swipe can pass several workspaces, like niri
        -- workspaces follow the fingers at a natural pace (a full workspace per
        -- ~260 units of travel), but a short swipe or a quick flick is enough to
        -- switch: letting go past 15% (default 50%) commits, as in niri
        workspace_swipe_distance           = 260,
        workspace_swipe_cancel_ratio       = 0.15,
        workspace_swipe_min_speed_to_force = 15,
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

-- maximize-column, as in niri: the column becomes 100% wide (an ordinary column,
-- so swiping still shows its neighbours), and again goes back to its old width.
-- (Hyprland's own "maximized" mode hides every other window on the workspace.)
local columnWidthBeforeMax = {}   -- window address -> width fraction
hl.bind(mainMod .. " + F", function ()
    local ok, w = pcall(hl.get_active_window)
    if not ok or not w then return end
    if (w.fullscreen or 0) ~= 0 then
        -- left over from Hyprland's maximized/fullscreen state: leave it first
        hl.dispatch(hl.dsp.window.fullscreen({ mode = (w.fullscreen == 1) and "maximized" or "fullscreen" }))
        return
    end
    local mon     = hl.get_active_monitor()
    local gapsOut = 14
    local usable  = mon.width / mon.scale - 2 * gapsOut
    local frac    = (w.size.x + 12) / usable   -- + gaps_in on both sides
    if frac > 0.95 then
        hl.dispatch(hl.dsp.layout(string.format("colresize %.3f", columnWidthBeforeMax[w.address] or 0.5)))
        columnWidthBeforeMax[w.address] = nil
    else
        columnWidthBeforeMax[w.address] = frac
        hl.dispatch(hl.dsp.layout("colresize 1.0"))
    end
end) -- maximize-column
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

---- SCRATCHPADS (pyprland; scratchpads are set up in ~/.config/pypr/config.toml) ----
-- Not in niri. pypr-client talks to the pypr daemon started in AUTOSTART.
hl.bind(mainMod .. " + grave",     exec("pypr-client toggle term"))  -- drop-down terminal
hl.bind(mainMod .. " + SHIFT + M", exec("pypr-client toggle music")) -- music player

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

-- (the bar, launcher and notifications get their glass in HYPRGLASS at the end)


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
                input = {
                    -- Workspaces follow the fingers at about the same pace as the swipe
                    -- outside the overview (the default 1.0 is far slower on the scale-1
                    -- laptop panel); letting go a fifth of the way moves on.
                    touchpad_scroll_factor = 3,
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


-------------------------
---- EDGE WORKSPACES ----
-------------------------

-- Our own plugin (edgeworkspaces/ next to this config's Nix module) keeps an
-- empty workspace ready above the first and below the last workspace on each
-- monitor, like niri's empty-workspace-above-first. Because they already exist,
-- swipes, Mod+U/I and the overview move onto them straight away instead of
-- creating one mid-gesture.
local okEdges, edgesPath = pcall(dofile, configDir .. "/edgeworkspaces-plugin.lua")
if okEdges and type(edgesPath) == "string" then
    hl.plugin.load(edgesPath)
end

local nirilikeLoaded = false
for _, plugin in ipairs(hl.get_loaded_plugins()) do
    if plugin.name == "edgeworkspaces" then
        nirilikeLoaded = true
        -- swipes stop at those empty ends instead of making more, as in niri
        hl.config({ gestures = { workspace_swipe_create_new = false } })
    end
end


----------------------
---- SCREEN SHARE ----
----------------------

-- Notifications never show up in a screen share (blacked out in the stream).
hl.layer_rule({
    name            = "no-share-notifications",
    match           = { namespace = "^notifications$" },
    no_screen_share = true,
})

-- Whatever is being shared gets a red border: the windows of a shared
-- workspace or monitor, or the shared window itself. Hyprland's picker
-- (xdg-desktop-portal-hyprland) can share a monitor, a window, a region or a
-- whole workspace; a shared workspace keeps streaming while you look elsewhere.
-- Shared windows are tagged "shared"; this rule colours tagged windows.
hl.window_rule({
    name         = "screenshare-border",
    match        = { tag = "shared" },
    border_size  = 3,   -- windows have no border otherwise
    border_color = "rgb(ff3b3b) rgb(ff3b3b)",
})

-- screenshare.state's type: 1 monitor, 2 window, 3 region, 4 workspace
local SHARE_MONITOR, SHARE_WINDOW, SHARE_WORKSPACE = 1, 2, 4
local shares = {}   -- active shares: { type, name, workspace? }

local function isShared(w)
    for _, s in ipairs(shares) do
        if s.type == SHARE_WORKSPACE and s.workspace and w.workspace == s.workspace then return true end
        if s.type == SHARE_MONITOR and w.monitor and w.monitor.name == s.name then return true end
        if s.type == SHARE_WINDOW and w.title == s.name then return true end
    end
    return false
end

local tagged = {}   -- address -> true for windows we tagged
local function updateShareBorders()
    for _, w in ipairs(hl.get_windows()) do
        local want = #shares > 0 and isShared(w)
        if want ~= (tagged[w.address] == true) then
            hl.dispatch(hl.dsp.window.tag({ tag = (want and "+" or "-") .. "shared", window = "address:" .. w.address }))
            tagged[w.address] = want or nil
        end
    end
end

hl.on("screenshare.state", function(active, shareType, name)
    if active then
        local entry = { type = shareType, name = name }
        if shareType == SHARE_WORKSPACE then
            -- follow the workspace itself: its number can change later
            for _, ws in ipairs(hl.get_workspaces()) do
                if ws.name == name then entry.workspace = ws end
            end
        end
        table.insert(shares, entry)
    else
        for i, s in ipairs(shares) do
            if s.type == shareType and s.name == name then
                table.remove(shares, i)
                break
            end
        end
    end
    updateShareBorders()
end)

-- keep it right as windows open, move or change title while sharing
for _, event in ipairs({ "window.open", "window.move_to_workspace", "window.title", "workspace.move_to_monitor" }) do
    hl.on(event, function()
        if #shares > 0 then updateShareBorders() end
    end)
end

-- 3 fingers left/right scrolls the columns. With the plugin it behaves like
-- niri: on release the view settles where a column lines up with a screen edge,
-- never past the first or last column, and moves focus one column per swipe.
-- Without it, Hyprland's own scroll_move (which can leave half the screen empty).
if nirilikeLoaded then
    hl.config({
        plugin = {
            edgeworkspaces = {
                swipe_distance  = 1200, -- touchpad travel per screen width of scrolling (niri: 1200; lower = faster)
                focus_threshold = 0.3,  -- how far into the next window a swipe must go to focus it (0.05 - 1)
                momentum        = 1,    -- how far a flick carries on after release (1 = like niri, 0 = none)
                center_columns  = true, -- swipes can also leave a window centred (niri only centres when two don't fit side by side)
            },
        },
    })
    hl.plugin.edgeworkspaces.scroll_gesture(3)
else
    hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
end


-------------------
---- HYPRGLASS ----
-------------------

-- Liquid Glass look (https://github.com/hyprnux/hyprglass): frosted blur with
-- refraction at the edges, a little colour fringing and glossy highlights, on
-- windows and on the bar, launcher and notifications. It replaces Hyprland's
-- own blur wherever it applies. Built for this exact Hyprland (hyprglass.nix).
local okGlass, glassPath = pcall(dofile, configDir .. "/hyprglass-plugin.lua")
if okGlass and type(glassPath) == "string" then
    hl.plugin.load(glassPath)
end

if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    -- Clear, colourful glass with a hint of sky blue. (The "light" theme washes
    -- everything out to white: brightness up, saturation down, and it lifts
    -- dark areas behind the glass towards white.)
    hg.config({
        default_theme        = "dark",
        tint_color           = 0x4fc3f714,   -- faint sky blue (RRGGBBAA)
        brightness           = 1.0,
        contrast             = 1.0,
        saturation           = 1.1,
        vibrancy             = 0.3,
        adaptive_dim         = 0.1,          -- keep very bright backgrounds from glaring
        adaptive_boost       = 0.0,          -- don't lift dark areas to white
        refraction_strength  = 0.75,         -- the liquid bend at the edges
        chromatic_aberration = 0.5,
        specular_strength    = 0.8,
        bevel_strength       = 0.5,          -- a thin lit line along the glass edge
        layers = { enabled = true },
    })

    -- glass on these layers only (others keep Hyprland's blur, if any)
    hg.layer("waybar", { preset = "subtle", mask_threshold = 0.05 })
    hg.layer("launcher")
    hg.layer("notifications", { mask_mode = "contour", mask_threshold = 0.15 })
else
    -- without the plugin: Hyprland's frosted blur behind the bar, launcher and
    -- notifications (only visible where they draw a translucent background)
    hl.layer_rule({
        name         = "blur-shell",
        match        = { namespace = "^(launcher|notifications|waybar)$" },
        blur         = true,
        ignore_alpha = 0.2,
    })
end
