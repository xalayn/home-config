-- Hyprland config (Lua, Hyprland 0.56)
-- Programs and keybinds match the niri setup; colors follow niri's
-- mauve -> teal focus ring.
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- Validate with: Hyprland --verify-config

local configDir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"


----------------
---- THEME  ----
----------------

-- One place for every color, so the borders, glow, groups and the
-- Phantomat HUD (spatialoverview.lua reads `theme`) stay in step.
theme = {
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

        layout = "dwindle",
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
            passes            = 3,
            noise             = 0.015,
            contrast          = 0.95,
            brightness        = 0.85,
            vibrancy          = 0.2,
            vibrancy_darkness = 0.4,
            popups            = true,
            special           = true,
            new_optimizations = true,
            xray              = false,
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
-- Springs for things that move, short eased fades for things that appear.
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeOutExpo",    { type = "bezier", points = { {0.16, 1},    {0.3, 1}     } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("smooth",         { type = "spring", mass = 1, stiffness = 90,  dampening = 17 })
hl.curve("bouncy",         { type = "spring", mass = 1, stiffness = 120, dampening = 15 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.4,  bezier = "easeOutQuint" })
hl.animation({ leaf = "borderangle",   enabled = true,  speed = 60,   bezier = "linear",       style = "loop" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.8,  spring = "smooth" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "bouncy",       style = "popin 85%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.6,  bezier = "easeOutExpo",  style = "popin 85%" })
hl.animation({ leaf = "windowsMove",   enabled = true,  speed = 4.8,  spring = "smooth" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.8,  bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.5,  bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3,    bezier = "quick" })
hl.animation({ leaf = "fadeDim",       enabled = true,  speed = 3,    bezier = "easeOutQuint" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.8,  bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutExpo",  style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.8,  bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.4,  bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 4,    spring = "smooth",       style = "slidefade 12%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4,  spring = "smooth",       style = "slidevert" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

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
-- (set general.layout = "scrolling" above for a niri-like layout)
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
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

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
        },
    },
})

-- Three-finger horizontal swipe switches workspaces
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- See https://wiki.hypr.land/Configuring/Basics/Binds/
-- Programs (same keys as niri)
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

-- Windows
hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())
hl.bind(mainMod .. " + S",         hl.dsp.layout("togglesplit"))    -- dwindle only

-- Exit Hyprland
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- Move focus with mainMod + arrows / hjkl, move windows with mainMod + CTRL
local directions = {
    left = "left", right = "right", up = "up", down = "down",
    H = "left", L = "right", K = "up", J = "down",
}
for key, dir in pairs(directions) do
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + CTRL + " .. key,      hl.dsp.window.move({ direction = dir }))
end

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + grave",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots (to the clipboard): Print = region, SHIFT + Print = whole screen
hl.bind("Print",         hl.dsp.exec_cmd("grim -g \"$(slurp -d -b 11111b88 -c dc8af1ff -w 2)\" - | wl-copy"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grim - | wl-copy"))

-- Multimedia keys for volume and brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

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


-------------------
---- PHANTOMAT ----
-------------------

-- Zoomable infinite-canvas plugin, built by home-manager
-- (alex-desktop.hyprland.phantomat). phantomat-plugin.lua holds the Nix store
-- path of the build; it is absent when the plugin is disabled. Loaded last so
-- its keybinds can override the ones above.
local ok, pluginPath = pcall(dofile, configDir .. "/phantomat-plugin.lua")
if ok and type(pluginPath) == "string" then
    hl.plugin.load(pluginPath)
    dofile(configDir .. "/spatialoverview.lua")
end
