-- Phantomat settings: a zoomable, infinite-canvas window manager for Hyprland.
-- https://github.com/kaolti/phantomat  (adapted from examples/spatialoverview.lua)
--
--   SUPER + O / SUPER + TAB   zoom out to the canvas; type to search, Enter to go
--   CTRL + ,                  (in the canvas) tune the look live; F1 lists every key
--
-- hyprland.lua loads this after the plugin. Edit and Hyprland reloads it, or
-- tune live: the tuner saves to spatialoverview-tuning.lua next to this file
-- (not managed by Nix), which is applied last.
--
-- Every bind below runs the canvas action when the canvas is up and falls
-- back to the normal Hyprland action from hyprland.lua otherwise.

local loaded = false
for _, plugin in ipairs(hl.get_loaded_plugins()) do
  if plugin.name == "spatialoverview" then
    loaded = true
    break
  end
end
-- On the first pass Hyprland has only been told to load the plugin; it
-- parses this file again once the plugin is in.
if not loaded then
  return
end

local accent = "#" .. ((theme and theme.mauve) or "dc8af1")

hl.config({
  plugin = {
    spatialoverview = {
      layout = "grid",
      scale = 0.36,
      workspace_gap = 0,
      grid = {
        columns = 3,
        stagger = 0.0,
      },

      input = {
        pan_sensitivity = 1.0,
        drag_threshold = 10,
        touchpad_scroll_factor = 1.0,
        scroll_event_delay = 160,
      },

      animation = {
        enabled = true,
        speed = 8.0,
        bezier = "spatialOverviewEase",
      },

      -- The curved lens when zoomed out. `strength` is signed; 0 is flat.
      distortion = {
        enabled = true,
        strength = 0.12,
        edge_scale = 1.08,
        feather = 0.025,
        transition_power = 1.0,
        edge_blur = 0.15,
        edge_blur_start = 0.55,
        vignette = 0.18,
        chromatic = 0.0,
      },

      workspace_outline = {
        enabled = false,
        width = 2,
        drop_width = 4,
        rounding = 14,
        opacity = 0.34,
        active_opacity = 0.82,
        drop_opacity = 1.0,
        drop_fill_opacity = 0.12,
      },

      canvas = {
        enabled = true,
        desktop_mode = true,    -- windows live on one shared 2D canvas
        persistent = true,
        initial_zoom = 0.72,
        min_zoom = 0.05,
        max_zoom = 2.5,
        zoom_step = 0.12,
        auto_float = true,
        auto_place = true,
        placement_gap = 28,     -- close to gaps_out in hyprland.lua
        space_pan = false,
        direct_input = true,
        hover_focus = true,
        minimap_enabled = true,
        minimap_width = 220,
        minimap_height = 138,
        minimap_margin = 24,
        minimap_opacity = 0.7,
        arrange_context_grouping = true,
        arrange_size_similarity = 0.12,
        arrange_resize_limit = 0.15,
        grid_enabled = true,
        grid_size = 80,
        grid_width = 1,
        grid_opacity = 0.12,
        grid_style = 1,         -- 0 lines, 1 dots
        grid_dot_size = 2.6,
        background_dim = 0.4,
        viewport_enabled = false,
        viewport_width = 3,
        viewport_rounding = 14,
        viewport_border_opacity = 0.90,
        viewport_outside_opacity = 0.26,
        float_on_drag = true,
        allow_window_overflow = true,
        snap_viewport_on_pan = true,
        commit_viewport_on_close = true,
        -- Off: the drag preview follows the mouse freely, but on drop the
        -- plugin rounds the position to the grid (grid_size, up to half a cell
        -- per axis), so windows landed somewhere other than where they looked.
        snap_enabled = false,
        remember_layout = true, -- windows keep their spots across restarts
      },

      -- Type-to-search palette in the zoomed-out canvas.
      navigator = {
        enabled = true,
        labels = true,
        dim_unmatched = 0.7,
        pointer = true,
        accent = accent,
        mono_font = "FiraCode Nerd Font",

        hud_scale = 1.0,
        width = 720,
        top = 0.075,
        rows = 6,
        row_height = 56,
        rounding = 14,          -- matches window rounding
        panel_opacity = 0.9,
        uppercase = false,
        letter_spacing = 0.4,
        query_size = 17,
        title_size = 14,
        detail_size = 10.5,
        corner_size = 12,
        label_size = 10.5,
        corner_labels = true,
        search_height = 58,
        search_border = 1.5,
        search_border_opacity = 0.85,
        search_border_color = "accent",
        search_glow = 0.35,
      },

      -- The wallpaper as a far layer that drifts slightly behind the windows.
      parallax = {
        enabled = true,
        strength = 0.06,
        depth = 0.12,
        desktop = false,
      },

      -- Slide waybar away while zoomed out.
      chrome_animation = {
        enabled = true,
        top_namespace = "waybar",
        bottom_namespace = "dock",  -- nothing uses it; kept so the option is valid
        top_travel = 1.35,
        bottom_travel = 1.08,
        top_scale = 0.82,
        bottom_scale = 0.92,
        opacity = 0.0,
      },

      wallpaper = 0,
      blur = true,
      blur_strength = 0.6,
      shadow = {
        enabled = true,
        range = 28,
      },
    },
  },
})

hl.curve("spatialOverviewEase", {
  type = "bezier",
  points = { { 0.22, 1.0 }, { 0.36, 1.0 } },
})

-- Settings changed with the live tuner (Ctrl+, in the zoomed-out canvas)
-- are saved to spatialoverview-tuning.lua and win over the values above.
-- Delete a line there to hand that setting back to this file.
if hl.plugin.spatialoverview.tuning_file then
  local ok, tuned = pcall(dofile, hl.plugin.spatialoverview.tuning_file())
  if ok and type(tuned) == "table" then
    local tree = {}
    for key, value in pairs(tuned) do
      local node, parts = tree, {}
      for part in string.gmatch(key, "[^:]+") do
        parts[#parts + 1] = part
      end
      for i = 1, #parts - 1 do
        node[parts[i]] = node[parts[i]] or {}
        node = node[parts[i]]
      end
      node[parts[#parts]] = value
    end
    hl.config({ plugin = { spatialoverview = tree } })
  end
end


-- ---- keybinds ---------------------------------------------------------------

local mainMod = "SUPER"

-- Replace a bind from hyprland.lua (or add a new one).
local function rebind(keys, action, opts)
  hl.unbind(keys)
  hl.bind(keys, action, opts)
end

-- Runs a canvas action, or the `fallback` dispatchers when the canvas is not
-- open. (Inside a function, hl.dsp.* only builds a dispatcher; hl.dispatch
-- runs it.)
local function canvas_or(action, fallback)
  return function()
    if not pcall(hl.plugin.spatialoverview.canvas, action) then
      for _, dispatcher in ipairs(fallback) do
        hl.dispatch(dispatcher)
      end
    end
  end
end

-- The canvas, on the same keys as niri's overview. The first press of a
-- session creates it and zooms out.
local function toggle_canvas()
  hl.plugin.spatialoverview.overview("toggle all")
end
rebind(mainMod .. " + O",          toggle_canvas)
rebind(mainMod .. " + TAB",        toggle_canvas)
rebind(mainMod .. " + CTRL + G",   toggle_canvas)

-- Alt+Tab walks windows most recently used first: a tap flips to the
-- previous one, holding Alt shows the list. Without the canvas it cycles.
rebind("ALT + TAB", canvas_or("switch next", {
  hl.dsp.window.cycle_next(),
  hl.dsp.window.bring_to_top(),
}), { repeating = true })
rebind("ALT + SHIFT + TAB", canvas_or("switch prev", {
  hl.dsp.window.cycle_next({ next = false }),
  hl.dsp.window.bring_to_top(),
}), { repeating = true })

-- Focus (arrows / hjkl): the nearest window that way; the camera follows.
-- Move (CTRL + arrows / hjkl): nudge the window a grid step on the canvas.
local directions = {
  left = "left", right = "right", up = "up", down = "down",
  H = "left", L = "right", K = "up", J = "down",
}
for key, dir in pairs(directions) do
  rebind(mainMod .. " + " .. key, function()
    if not pcall(hl.plugin.spatialoverview.navigate, dir) then
      hl.dispatch(hl.dsp.focus({ direction = dir }))
    end
  end)
  rebind(mainMod .. " + CTRL + " .. key, canvas_or("nudge " .. dir, {
    hl.dsp.window.move({ direction = dir }),
  }), { repeating = true })
end

-- On the canvas every window floats, so the float toggle fills the screen
-- instead (press again to put it back), and the tiling keys do nothing.
rebind(mainMod .. " + V", canvas_or("fill", { hl.dsp.window.float({ action = "toggle" }) }))
rebind(mainMod .. " + P", canvas_or("noop", { hl.dsp.window.pseudo() }))
rebind(mainMod .. " + S", canvas_or("noop", { hl.dsp.layout("togglesplit") }))

-- Pin the window to the screen, out of the canvas (again puts it back).
rebind(mainMod .. " + SHIFT + P", canvas_or("pin", { hl.dsp.window.pin() }))

-- Workspaces are places on the canvas: SUPER + 1…0 go to a place,
-- SUPER + SHIFT + N sends the focused window there.
for i = 1, 10 do
  local key = tostring(i % 10)
  rebind(mainMod .. " + " .. key,
    canvas_or("go " .. i, { hl.dsp.focus({ workspace = i }) }))
  rebind(mainMod .. " + SHIFT + " .. key,
    canvas_or("send " .. i, { hl.dsp.window.move({ workspace = i }) }))
end

-- SUPER + scroll: the place (or workspace) next door.
rebind(mainMod .. " + mouse_down", canvas_or("go next", { hl.dsp.focus({ workspace = "e+1" }) }))
rebind(mainMod .. " + mouse_up",   canvas_or("go prev", { hl.dsp.focus({ workspace = "e-1" }) }))
