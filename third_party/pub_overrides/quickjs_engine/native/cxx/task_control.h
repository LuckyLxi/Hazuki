// Control records contain no QuickJS pointers. Only the owning worker touches JS.
#pragma once
#include <atomic>
#include <mutex>
#include <memory>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace hazuki_tasks {
struct Task { bool completed = false; std::atomic<int> stop{0}; uint64_t entry = 0; };
struct Work {
    uint64_t task = 0;
    int refs = 0;
    bool live = true;
    std::unordered_set<uint64_t> dependencies;
};
struct Control {
    std::mutex mutex;
    bool closed = false;
    std::unordered_map<uint64_t, std::shared_ptr<Task>> tasks;
    std::unordered_map<uint64_t, Work> works;

    // Graph edges do not own memory. JS captures own records, including cycles.
    // Reachability, rather than a reference count, determines execution liveness.
    void refresh() {
        std::vector<uint64_t> pending;
        for (auto &item : works) {
            auto task = tasks.find(item.second.task);
            item.second.live = item.second.task == 0 || task == tasks.end() ||
                (!task->second->completed && task->second->stop.load() == 0);
            if (item.second.live) pending.push_back(item.first);
        }
        while (!pending.empty()) {
            auto id = pending.back(); pending.pop_back();
            auto it = works.find(id);
            if (it == works.end()) continue;
            for (auto dependency : it->second.dependencies) {
                auto found = works.find(dependency);
                if (found != works.end() && !found->second.live) {
                    found->second.live = true;
                    pending.push_back(dependency);
                }
            }
        }
    }
    void collect() {
        for (auto it = works.begin(); it != works.end();) {
            if (it->second.refs <= 0) it = works.erase(it); else ++it;
        }
        for (auto it = tasks.begin(); it != tasks.end();) {
            bool referenced = false;
            for (const auto &work : works)
                if (work.second.task == it->first) { referenced = true; break; }
            if (it->second->completed && !referenced) it = tasks.erase(it); else ++it;
        }
        refresh();
    }
};
inline std::mutex registry_mutex;
inline std::unordered_map<uint64_t, std::shared_ptr<Control>> registry;
inline std::atomic<uint64_t> next_id{1};
inline std::shared_ptr<Control> find(uint64_t id) {
    std::lock_guard<std::mutex> lock(registry_mutex);
    auto it = registry.find(id);
    return it == registry.end() ? nullptr : it->second;
}
// JS work operations: create, retain, release, depend, stop, entry, disconnect,
// and the raw caller stop state (observers do not protect shared work).
inline uint64_t work(JSRuntime *, int op, uint64_t a, uint64_t b, void *opaque) {
    auto *control = static_cast<Control *>(opaque);
    std::lock_guard<std::mutex> lock(control->mutex);
    if (op == 1) {
        uint64_t id = next_id.fetch_add(1);
        control->works.emplace(id, Work{a, 1, true, {}});
        control->refresh();
        return id;
    }
    if (op == 6) {
        auto task = control->tasks.find(a);
        return task == control->tasks.end() ? 0 : task->second->entry;
    }
    if (op == 8) {
        auto task = control->tasks.find(a);
        return task == control->tasks.end() ? 0 : task->second->stop.load();
    }
    auto it = control->works.find(a);
    if (it == control->works.end()) return 0;
    if (op == 2) ++it->second.refs;
    if (op == 3) { --it->second.refs; control->collect(); }
    if (op == 4) { if (b && b != a) it->second.dependencies.insert(b); control->refresh(); }
    if (op == 7) { it->second.dependencies.clear(); control->refresh(); }
    if (op == 5 && !it->second.live) {
        auto task = control->tasks.find(it->second.task);
        return task == control->tasks.end() ? 0 : task->second->stop.load();
    }
    return 0;
}
}
