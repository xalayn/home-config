// edgeworkspaces: niri's empty workspaces at both ends, kept ready ahead of time.
//
// Every monitor that has windows keeps one empty workspace just above its first
// workspace and one just below its last (by workspace id). They are created as
// soon as they're needed and marked persistent so Hyprland doesn't delete them,
// so swiping, keybinds and the ScrollOverview overview land on a workspace that
// already exists instead of creating one mid-gesture.
//
// It also provides a niri-style horizontal swipe for the scrolling layout
// (hl.plugin.edgeworkspaces.scroll_gesture(fingers)): columns follow the
// fingers, and on release the view settles on the nearest position where a
// column lines up with a screen edge, never past the first or last column, and
// moves focus at most one column per swipe when nothing needs to scroll.
//
// Settings (hyprland.lua): hl.config({ plugin = { edgeworkspaces = {
//     swipe_distance = 1200, focus_threshold = 0.3, momentum = 1, center_columns = true } } })
//
// Lua (for debugging): hl.plugin.edgeworkspaces.status(), .reconcile()

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/managers/input/UnifiedWorkspaceSwipeGesture.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <hyprland/src/state/WorkspaceState.hpp>
#include <hyprland/src/state/workspace/Resolver.hpp>
#include <hyprland/src/workspace/RegularWorkspace.hpp>
#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/config/values/types/FloatValue.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/plugins/HookSystem.hpp>
#include <hyprland/src/input/Keys.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowFullscreenPolicy.hpp>
#include <hyprland/src/layout/target/WindowTarget.hpp>
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/managers/input/trackpad/TrackpadGestures.hpp>
#include <hyprland/src/managers/input/trackpad/gestures/ITrackpadGesture.hpp>
#define private public
#include <hyprland/src/layout/algorithm/tiled/scrolling/ScrollingAlgorithm.hpp>
#include <hyprland/src/layout/algorithm/tiled/scrolling/ScrollTapeController.hpp>
#include <hyprland/src/layout/algorithm/tiled/scrolling/ScrollingFullscreenHandler.hpp>
#undef private
#include <cmath>
#include <deque>

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

#include <algorithm>
#include <format>
#include <optional>
#include <string>
#include <vector>

static HANDLE                           g_handle = nullptr;
static std::vector<PHLWORKSPACEREF>     g_ours;
static std::vector<CHyprSignalListener> g_listeners;
static bool                             g_pending = false;
static bool                             g_enabled = false;
static std::string                      g_lastResult = "never ran";
static uint64_t                         g_runs       = 0;

static bool isRegularNumbered(const PHLWORKSPACE& ws) {
    return ws && ws->type() != Workspace::eWorkspaceType::SPECIAL && ws->numberedID().has_value();
}

static void setPersistent(const PHLWORKSPACE& ws, bool on) {
    if (isRegularNumbered(ws))
        sc<Workspace::CRegularWorkspace*>(ws.get())->setPersistent(on);
}

static PHLWORKSPACE createAt(int64_t id, const PHLMONITOR& monitor, std::string& log) {
    if (id < 1) {
        log += std::format(" [no room for id {}]", id);
        return nullptr;
    }
    const auto TARGET = State::Workspace::resolver()->getWorkspaceTargetFromString(std::to_string(id), monitor);
    if (!TARGET.valid()) {
        log += std::format(" [target {} invalid]", id);
        return nullptr;
    }
    if (State::Workspace::state()->find(TARGET)) {
        log += std::format(" [id {} taken]", id);
        return nullptr;
    }
    const auto WS = State::Workspace::state()->createNumbered(Workspace::SWorkspaceNumberedID{sc<Workspace::WorkspaceIDContainer>(id)}, monitor);
    if (!WS) {
        log += std::format(" [create {} failed]", id);
        return nullptr;
    }
    setPersistent(WS, true); // before anything can clean it up
    WS->ready();
    log += std::format(" [created {}]", id);
    return WS;
}

static void reconcile() {
    g_pending = false;
    if (!g_enabled)
        return;

    g_runs++;

    // don't reshuffle workspaces under a running swipe; its end schedules us again
    if (g_pUnifiedWorkspaceSwipe && g_pUnifiedWorkspaceSwipe->isGestureInProgress()) {
        g_lastResult = "skipped: swipe in progress";
        return;
    }

    std::string               log;
    std::vector<PHLWORKSPACE> keep;

    for (const auto& monitor : State::monitorState()->monitors()) {
        if (!monitor)
            continue;

        std::vector<PHLWORKSPACE> list;
        for (const auto& w : State::workspaceState()->workspaces()) {
            const auto WS = w.lock();
            if (!WS || WS->m_monitor != monitor || !isRegularNumbered(WS))
                continue;
            list.push_back(WS);
        }
        std::ranges::sort(list, [](const auto& a, const auto& b) { return *a->numberedID() < *b->numberedID(); });

        log += std::format("{}:", monitor->m_name);
        for (const auto& ws : list)
            log += std::format(" {}({})", *ws->numberedID(), ws->getWindowCount());

        std::optional<size_t> first, last;
        for (size_t i = 0; i < list.size(); ++i) {
            if (list[i]->getWindowCount() == 0)
                continue;
            if (!first)
                first = i;
            last = i;
        }

        if (!first) { // nothing open on this monitor: one empty workspace, as in niri
            log += " [no windows]; ";
            continue;
        }

        // above: reuse an empty one already there (prefer the focused one), else create one
        if (*first == 0) {
            if (const auto WS = createAt(sc<int64_t>(*list.front()->numberedID()) - 1, monitor, log))
                keep.push_back(WS);
        } else {
            PHLWORKSPACE pick = list[*first - 1];
            for (size_t i = 0; i < *first; ++i)
                if (monitor->m_activeWorkspace == list[i])
                    pick = list[i];
            keep.push_back(pick);
        }

        // below
        if (*last == list.size() - 1) {
            if (const auto WS = createAt(sc<int64_t>(*list.back()->numberedID()) + 1, monitor, log))
                keep.push_back(WS);
        } else {
            PHLWORKSPACE pick = list[*last + 1];
            for (size_t i = *last + 1; i < list.size(); ++i)
                if (monitor->m_activeWorkspace == list[i])
                    pick = list[i];
            keep.push_back(pick);
        }
        log += "; ";
    }

    // release edge workspaces that are no longer at an edge (Hyprland then
    // removes them like any other empty workspace you're not on)
    for (const auto& ref : g_ours) {
        const auto WS = ref.lock();
        if (WS && std::ranges::find(keep, WS) == keep.end())
            setPersistent(WS, false);
    }

    g_ours.clear();
    log += "edges:";
    for (const auto& WS : keep) {
        setPersistent(WS, true);
        g_ours.push_back(WS);
        log += std::format(" {}", *WS->numberedID());
    }

    g_lastResult = log;
}

static void schedule() {
    if (g_pending || !g_enabled)
        return;
    g_pending = true;
    g_pEventLoopManager->doLater([] { reconcile(); });
}

// ---------------------------------------------------------------------------
// niri-style horizontal swipe for the scrolling layout
// ---------------------------------------------------------------------------

static Layout::Tiled::CScrollingAlgorithm* currentScrollingLayout() {
    const auto MONITOR = Desktop::focusState()->monitor();
    if (!MONITOR)
        return nullptr;
    const auto WS = MONITOR->m_activeSpecialWorkspace ? MONITOR->m_activeSpecialWorkspace : MONITOR->m_activeWorkspace;
    if (!WS || !WS->space())
        return nullptr;
    const auto ALGO = WS->space()->algorithm();
    if (!ALGO || !ALGO->tiledAlgo())
        return nullptr;
    return dynamic_cast<Layout::Tiled::CScrollingAlgorithm*>(ALGO->tiledAlgo().get());
}

// Settings, set from hyprland.lua:
//   hl.config({ plugin = { edgeworkspaces = { swipe_distance = 1200, ... } } })
static double cfgSwipeDistance() { // touchpad travel to move the view one screen width (niri: 1200)
    static auto P = CConfigValue<Config::FLOAT>("plugin:edgeworkspaces:swipe_distance");
    return std::max<double>(50.0, *P);
}
static double cfgFocusThreshold() { // how far into the next window focus moves (fraction of its width)
    static auto P = CConfigValue<Config::FLOAT>("plugin:edgeworkspaces:focus_threshold");
    return std::clamp<double>(*P, 0.05, 1.0);
}
static double cfgMomentum() { // how far a flick carries on, 1 = like niri, 0 = not at all
    static auto P = CConfigValue<Config::FLOAT>("plugin:edgeworkspaces:momentum");
    return std::clamp<double>(*P, 0.0, 3.0);
}
static bool cfgCenterColumns() { // swipes can also leave a window centred
    static auto P = CConfigValue<Config::BOOL>("plugin:edgeworkspaces:center_columns");
    return *P;
}

static std::string g_lastGesture = "no swipe yet";

// While a swipe is in progress, Hyprland's scrolling layout would keep
// re-centring the view (when everything fits) or pulling it back to the first
// column on every frame, so the windows wouldn't follow the fingers. This hook
// leaves the dragged workspace's view where the fingers put it.
static Layout::Tiled::CScrollTapeController* g_draggedTape    = nullptr;
static CFunctionHook*                        g_cameraHook     = nullptr;
using FCameraOffset                                          = double (*)(Layout::Tiled::CScrollTapeController*, const CBox&, bool);

static double hkCalculateCameraOffset(Layout::Tiled::CScrollTapeController* tape, const CBox& area, bool fullscreenOnOne) {
    if (tape && tape == g_draggedTape)
        return tape->m_offset;
    return rc<FCameraOffset>(g_cameraHook->m_original)(tape, area, fullscreenOnOne);
}

// A port of niri's view_offset_gesture_* (src/layout/scrolling.rs) and its
// SwipeTracker (src/input/swipe_tracker.rs), for center-focused-column
// "on-overflow" as in the niri config:
//  - one working-area width of view movement per 1200 units of touchpad travel
//  - velocity over the last 150 ms; the release projects where the motion would
//    stop with deceleration 0.997/ms
//  - snapping points: each column's left/right edge lined up with the view,
//    or centred when it overflows together with its neighbour, never beyond the
//    first/last column
// One deliberate difference: focus follows the swipe distance (one window per
// short swipe, more for longer ones) rather than jumping to the furthest
// visible window, and the view then shows that window with the least scrolling.
class CNiriScrollGesture : public ITrackpadGesture {
  public:
    void begin(const STrackpadGestureBegin& e) override {
        ITrackpadGesture::begin(e);
        m_history.clear();
        m_pos    = 0.0;
        m_layout = currentScrollingLayout();
        if (!m_layout || !m_layout->m_scrollingData || !m_layout->m_scrollingData->controller)
            m_layout = nullptr;
        else {
            m_startOffset   = m_layout->m_scrollingData->controller->getOffset();
            const auto COL  = m_layout->currentColumn();
            m_startIndex    = COL ? m_layout->m_scrollingData->idx(COL) : -1;
            g_draggedTape   = m_layout->m_scrollingData->controller.get();
        }
    }

    void update(const STrackpadGestureUpdate& e) override {
        if (!m_layout || m_layout != currentScrollingLayout() || !e.swipe)
            return;
        // same direction convention as Hyprland's scroll_move (natural scrolling)
        const double DELTA = -e.swipe->delta.x * e.scale;
        push(DELTA, e.swipe->timeMs / 1000.0);

        auto& TAPE = *m_layout->m_scrollingData->controller;
        TAPE.setOffset(m_startOffset + m_pos * normFactor(m_layout));
        m_layout->m_scrollingData->recalculate(true); // follow the fingers exactly
    }

    void end(const STrackpadGestureEnd& e) override {
        const auto LAYOUT = m_layout;
        m_layout          = nullptr;
        g_draggedTape     = nullptr; // the layout manages the view again from here
        if (!LAYOUT || LAYOUT != currentScrollingLayout() || !LAYOUT->m_scrollingData || !LAYOUT->m_scrollingData->controller)
            return;

        static auto PFSONONE = CConfigValue<Config::INTEGER>("scrolling:fullscreen_on_one_column");
        auto&       DATA     = *LAYOUT->m_scrollingData;
        auto&       TAPE     = *DATA.controller;
        const CBox  AREA     = LAYOUT->usableArea();
        const bool  FS1      = *PFSONONE;
        const double VIEW    = TAPE.isPrimaryHorizontal() ? AREA.w : AREA.h;
        const size_t N       = std::min(TAPE.stripCount(), DATA.columns.size());
        if (N == 0 || VIEW <= 0.0)
            return;

        // account for idle time between the last event and now
        if (!m_history.empty())
            push(0.0, nowSeconds(e));

        const double NORM    = normFactor(LAYOUT);
        const double CURRENT = m_startOffset + m_pos * NORM;
        const double TARGET  = m_startOffset + projectedEndPos() * NORM;

        std::vector<double> start(N), size(N);
        for (size_t i = 0; i < N; ++i) {
            start[i] = TAPE.calculateStripStart(i, AREA, FS1);
            size[i]  = TAPE.calculateStripSize(i, AREA, FS1);
        }

        // snap points for a column; the usable area already excludes outer gaps,
        // and a column overflows with a neighbour if both don't fit side by side
        auto snapPoints = [&](size_t i) {
            const double CENTER = size[i] >= VIEW ? start[i] : start[i] - (VIEW - size[i]) / 2.0;
            const bool   OVERFLOW_NEXT = i + 1 < N && (start[i + 1] + size[i + 1]) - start[i] > VIEW + 0.5;
            const bool   OVERFLOW_PREV = i > 0 && (start[i] + size[i]) - start[i - 1] > VIEW + 0.5;
            const double LEFT  = OVERFLOW_NEXT ? CENTER : start[i];
            const double RIGHT = (OVERFLOW_PREV ? CENTER + VIEW : start[i] + size[i]) - VIEW;
            return std::pair{LEFT, RIGHT};
        };

        struct SSnap {
            double pos;
            size_t col;
        };
        std::vector<SSnap> snaps;
        const double       LEFTMOST  = snapPoints(0).first;
        const double       RIGHTMOST = snapPoints(N - 1).second;
        snaps.push_back({LEFTMOST, 0});
        snaps.push_back({RIGHTMOST, N - 1});
        for (size_t i = 0; i < N; ++i) {
            const auto [LEFT, RIGHT] = snapPoints(i);
            if (LEFTMOST < LEFT && LEFT < RIGHTMOST)
                snaps.push_back({LEFT, i});
            if (LEFTMOST < RIGHT && RIGHT < RIGHTMOST)
                snaps.push_back({RIGHT, i});
            // also a centred position for every window (not in niri, where
            // on-overflow only centres windows that don't fit beside a neighbour)
            if (cfgCenterColumns() && size[i] < VIEW) {
                const double CENTER = start[i] - (VIEW - size[i]) / 2.0;
                if (LEFTMOST < CENTER && CENTER < RIGHTMOST)
                    snaps.push_back({CENTER, i});
            }
        }
        std::ranges::stable_sort(snaps, [](const auto& a, const auto& b) { return a.pos < b.pos; });

        // Focus follows how far the fingers actually moved (not niri's
        // "furthest visible column", and not the flick projection, which would
        // skip windows): focus steps one window each time the drag gets
        // focus_threshold of the way into the next one. A flick that barely
        // moved still steps one window, in the direction of the flick.
        const size_t STARTCOL = m_startIndex >= 0 && sc<size_t>(m_startIndex) < N ? sc<size_t>(m_startIndex) : 0;
        auto         stepFrom = [&](double displacement) {
            size_t    c         = STARTCOL;
            double    remaining = std::abs(displacement);
            const int DIR       = displacement > 0 ? 1 : -1;
            while (true) {
                const long NEXT = sc<long>(c) + DIR;
                if (NEXT < 0 || NEXT >= sc<long>(N) || remaining < cfgFocusThreshold() * size[NEXT])
                    break;
                remaining -= size[NEXT];
                c = sc<size_t>(NEXT);
                if (remaining <= 0.0)
                    break;
            }
            return c;
        };
        size_t col = STARTCOL;
        if (m_startIndex >= 0) {
            col = stepFrom(CURRENT - m_startOffset);
            if (col == STARTCOL && cfgMomentum() > 0.0) {
                const size_t FLICKED = stepFrom(TARGET - m_startOffset);
                if (FLICKED != STARTCOL)
                    col = FLICKED > STARTCOL ? STARTCOL + 1 : STARTCOL - 1;
            }
        }

        // Where the view settles: the focused window centred, if that's one of
        // the resting points (center_columns); otherwise the resting point that
        // shows it fully and is closest to where the drag left the view.
        const double REF  = col == STARTCOL || CURRENT != m_startOffset ? CURRENT : TARGET;
        const SSnap* best = nullptr;
        for (const auto& s : snaps) {
            const bool SHOWS = size[col] >= VIEW ? (s.col == col) : (start[col] >= s.pos - 0.5 && start[col] + size[col] <= s.pos + VIEW + 0.5);
            if (!SHOWS)
                continue;
            const bool CENTRED = cfgCenterColumns() && size[col] < VIEW && std::abs(s.pos - (start[col] - (VIEW - size[col]) / 2.0)) < 0.5;
            if (CENTRED) {
                best = &s;
                break;
            }
            if (!best || std::abs(s.pos - REF) < std::abs(best->pos - REF))
                best = &s;
        }
        double offset = 0.0;
        if (best)
            offset = best->pos;
        else // e.g. a column wider than the screen: line up its nearer edge
            offset = std::clamp(REF, std::min(start[col], start[col] + size[col] - VIEW), std::max(start[col], start[col] + size[col] - VIEW));

        std::string dbg = std::format("view={:.0f} start={:.0f} startcol={} now={:.0f} target={:.0f} -> col={} offset={:.0f}; snaps:", VIEW, m_startOffset, m_startIndex, CURRENT, TARGET, col, offset);
        for (const auto& s : snaps)
            dbg += std::format(" {:.0f}(c{})", s.pos, s.col);

        TAPE.setOffset(offset);
        DATA.recalculate(); // animated, like niri's horizontal-view-movement
        LAYOUT->focusColumn(DATA.columns[col]);
        g_lastGesture = dbg + std::format("; after focus offset={:.0f}", TAPE.getOffset());
    }

  private:
    struct SEvent {
        double delta;
        double time;
    };

    // view movement per unit of touchpad travel: one working area per 1200 units
    static double normFactor(Layout::Tiled::CScrollingAlgorithm* layout) {
        const CBox AREA = layout->usableArea();
        return (layout->m_scrollingData->controller->isPrimaryHorizontal() ? AREA.w : AREA.h) / cfgSwipeDistance();
    }

    void push(double delta, double time) {
        if (!m_history.empty() && time < m_history.back().time)
            return;
        m_history.push_back({delta, time});
        m_pos += delta;
        while (!m_history.empty() && m_history.back().time > m_history.front().time + 0.150)
            m_history.pop_front();
    }

    double velocity() const {
        if (m_history.size() < 2)
            return 0.0;
        const double DT = m_history.back().time - m_history.front().time;
        if (DT <= 0.0)
            return 0.0;
        double total = 0.0;
        for (const auto& ev : m_history)
            total += ev.delta;
        return total / DT;
    }

    double projectedEndPos() const {
        return m_pos - cfgMomentum() * velocity() / (1000.0 * std::log(0.997));
    }

    double nowSeconds(const STrackpadGestureEnd& e) const {
        return e.swipe ? e.swipe->timeMs / 1000.0 : m_history.back().time;
    }

    Layout::Tiled::CScrollingAlgorithm* m_layout      = nullptr;
    double                              m_startOffset = 0.0;
    long                                m_startIndex  = -1;
    double                              m_pos         = 0.0;
    std::deque<SEvent>                  m_history;
};

static std::vector<size_t> g_gestureFingers;

static int luaScrollGesture(lua_State* L) {
    const auto FINGERS = sc<size_t>(luaL_optinteger(L, 1, 3));
    const auto RESULT  = g_pTrackpadGestures->addGesture(makeUnique<CNiriScrollGesture>(), FINGERS, TRACKPAD_GESTURE_DIR_HORIZONTAL, Input::ModifierMask{Input::HL_MODIFIER_NONE}, 1.F, false);
    if (!RESULT)
        return luaL_error(L, "scroll_gesture: %s", RESULT.error().c_str());
    g_gestureFingers.push_back(FINGERS);
    return 0;
}

static int luaLastGesture(lua_State* L) {
    lua_pushstring(L, g_lastGesture.c_str());
    return 1;
}

// debug: run a swipe of `units` touchpad units (negative = the other way)
// through the gesture, as several updates over ~150 ms, then release
static CNiriScrollGesture* g_heldGesture = nullptr;

static int luaSimulateSwipe(lua_State* L) {
    const double       UNITS = luaL_checknumber(L, 1);
    CNiriScrollGesture g;
    uint32_t           t = 0;
    IPointer::SSwipeUpdateEvent first{.timeMs = t, .fingers = 3, .delta = Vector2D{0.0, 0.0}};
    g.begin({.swipe = &first, .direction = TRACKPAD_GESTURE_DIR_HORIZONTAL, .scale = 1.F});
    for (int i = 1; i <= 10; ++i) {
        t += 15;
        IPointer::SSwipeUpdateEvent ev{.timeMs = t, .fingers = 3, .delta = Vector2D{UNITS / 10.0, 0.0}};
        g.update({.swipe = &ev, .direction = TRACKPAD_GESTURE_DIR_HORIZONTAL, .scale = 1.F});
    }
    // a second argument `true` keeps the fingers "down": finish with simulate_release()
    if (lua_toboolean(L, 2)) {
        static CNiriScrollGesture held;
        held = g;
        g_heldGesture = &held;
        lua_pushstring(L, "holding");
        return 1;
    }
    IPointer::SSwipeEndEvent end{.timeMs = t + 5, .cancelled = false};
    g.end({.swipe = &end, .direction = TRACKPAD_GESTURE_DIR_HORIZONTAL, .scale = 1.F});
    return luaLastGesture(L);
}

static int luaSimulateRelease(lua_State* L) {
    if (!g_heldGesture) {
        lua_pushstring(L, "no held swipe");
        return 1;
    }
    IPointer::SSwipeEndEvent end{.timeMs = 1000, .cancelled = false};
    g_heldGesture->end({.swipe = &end, .direction = TRACKPAD_GESTURE_DIR_HORIZONTAL, .scale = 1.F});
    g_heldGesture = nullptr;
    return luaLastGesture(L);
}

static int luaStatus(lua_State* L) {
    std::string s = std::format("enabled={} pending={} runs={} | {}", g_enabled, g_pending, g_runs, g_lastResult);
    lua_pushstring(L, s.c_str());
    return 1;
}

static int luaReconcile(lua_State* L) {
    reconcile();
    return luaStatus(L);
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    g_handle = handle;

    if (std::string{__hyprland_api_get_hash()} != std::string{__hyprland_api_get_client_hash()})
        throw std::runtime_error("[edgeworkspaces] Version mismatch (headers ver is not equal to running hyprland ver)");

    HyprlandAPI::addLuaFunction(handle, "edgeworkspaces", "status", luaStatus);
    HyprlandAPI::addLuaFunction(handle, "edgeworkspaces", "reconcile", luaReconcile);
    HyprlandAPI::addLuaFunction(handle, "edgeworkspaces", "scroll_gesture", luaScrollGesture);
    HyprlandAPI::addLuaFunction(handle, "edgeworkspaces", "last_swipe", luaLastGesture);
    HyprlandAPI::addLuaFunction(handle, "edgeworkspaces", "simulate_swipe", luaSimulateSwipe);
    HyprlandAPI::addLuaFunction(handle, "edgeworkspaces", "simulate_release", luaSimulateRelease);

    using namespace Config::Values;
    HyprlandAPI::addConfigValueV2(handle, makeShared<CFloatValue>("plugin:edgeworkspaces:swipe_distance",
        "touchpad travel that moves the view one screen width (niri: 1200)", 1200.F, SFloatValueOptions{.min = 50.F}));
    HyprlandAPI::addConfigValueV2(handle, makeShared<CFloatValue>("plugin:edgeworkspaces:focus_threshold",
        "how far into the next window (fraction of its width) a swipe must go to focus it", 0.3F, SFloatValueOptions{.min = 0.05F, .max = 1.F}));
    HyprlandAPI::addConfigValueV2(handle, makeShared<CFloatValue>("plugin:edgeworkspaces:momentum",
        "how far a flick carries on after release: 1 = like niri, 0 = none", 1.F, SFloatValueOptions{.min = 0.F, .max = 3.F}));
    HyprlandAPI::addConfigValueV2(handle, makeShared<CBoolValue>("plugin:edgeworkspaces:center_columns",
        "swipes can also settle with a window centred, not only lined up with a screen edge", true));

    const auto CAMERA = HyprlandAPI::findFunctionsByName(handle, "calculateCameraOffset");
    for (const auto& fn : CAMERA) {
        if (fn.demangled.find("CScrollTapeController::calculateCameraOffset") == std::string::npos)
            continue;
        g_cameraHook = HyprlandAPI::createFunctionHook(handle, fn.address, rc<void*>(hkCalculateCameraOffset));
        if (g_cameraHook && !g_cameraHook->hook())
            g_cameraHook = nullptr;
        break;
    }
    if (!g_cameraHook)
        HyprlandAPI::addNotification(handle, "[edgeworkspaces] couldn't hook the scrolling layout; swipes may stick at the ends", CHyprColor{1.0, 0.6, 0.2, 1.0}, 5000);

    HyprlandAPI::reloadConfig();

    g_enabled = true;
    auto& ev  = Event::bus()->m_events;
    g_listeners.push_back(ev.window.open.listen([](PHLWINDOW) { schedule(); }));
    g_listeners.push_back(ev.window.destroy.listen([](PHLWINDOWREF) { schedule(); }));
    g_listeners.push_back(ev.window.moveToWorkspace.listen([](PHLWINDOW, PHLWORKSPACE) { schedule(); }));
    g_listeners.push_back(ev.workspace.active.listen([](PHLWORKSPACE) { schedule(); }));
    g_listeners.push_back(ev.workspace.removed.listen([](PHLWORKSPACEREF) { schedule(); }));
    g_listeners.push_back(ev.workspace.moveToMonitor.listen([](PHLWORKSPACE, PHLMONITOR) { schedule(); }));
    g_listeners.push_back(ev.monitor.added.listen([](PHLMONITOR) { schedule(); }));
    g_listeners.push_back(ev.config.reloaded.listen([] { schedule(); }));
    g_listeners.push_back(ev.gesture.swipe.end.listen([](const IPointer::SSwipeEndEvent&, Event::SCallbackInfo&) { schedule(); }));
    schedule();

    return {"edgeworkspaces", "Empty workspaces kept ready at both ends, like niri", "alex", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    for (const auto FINGERS : g_gestureFingers)
        (void)g_pTrackpadGestures->removeGesture(FINGERS, TRACKPAD_GESTURE_DIR_HORIZONTAL, Input::ModifierMask{Input::HL_MODIFIER_NONE}, 1.F, false);
    g_gestureFingers.clear();
    g_draggedTape = nullptr;
    if (g_cameraHook)
        HyprlandAPI::removeFunctionHook(g_handle, g_cameraHook);
    g_cameraHook = nullptr;
    g_enabled = false;
    g_listeners.clear();
    for (const auto& ref : g_ours)
        if (const auto WS = ref.lock())
            setPersistent(WS, false);
    g_ours.clear();
}
