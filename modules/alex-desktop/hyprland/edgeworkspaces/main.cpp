// edgeworkspaces: niri's empty workspaces at both ends, kept ready ahead of time.
//
// Every monitor that has windows keeps one empty workspace just above its first
// workspace and one just below its last (by workspace id). They are created as
// soon as they're needed and marked persistent so Hyprland doesn't delete them,
// so swiping, keybinds and the ScrollOverview overview land on a workspace that
// already exists instead of creating one mid-gesture.
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

extern "C" {
#include <lua.h>
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
    g_enabled = false;
    g_listeners.clear();
    for (const auto& ref : g_ours)
        if (const auto WS = ref.lock())
            setPersistent(WS, false);
    g_ours.clear();
}
