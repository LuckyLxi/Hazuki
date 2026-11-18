// Control records contain no QuickJS pointers. Only the owning worker touches JS.
#pragma once
#include <atomic>
#include <mutex>
#include <memory>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <condition_variable>

namespace hazuki_tasks {
struct Mailbox {
    std::mutex mutex;
    std::condition_variable changed;
    bool ready = false;
    bool closed = false;
    int stop_reason = 0;
    uint64_t task = 0, work = 0;
    std::vector<uint8_t> bytes;
};
struct Task { bool completed = false; std::atomic<int> stop{0}; uint64_t entry = 0; };
struct Work {
    uint64_t task = 0;
    int refs = 0;
    bool live = true;
    std::unordered_set<uint64_t> dependencies;
    int claimed_stop = 0;
};
struct Control {
    std::mutex mutex;
    bool closed = false;
    std::unordered_map<uint64_t, std::shared_ptr<Task>> tasks;
    std::unordered_map<uint64_t, Work> works;
    std::vector<std::weak_ptr<Mailbox>> mailboxes;

    int stop_reason(const Work &work) const {
        if (work.claimed_stop) return work.claimed_stop;
        auto task = tasks.find(work.task);
        return !work.live && task != tasks.end() ? task->second->stop.load() : 0;
    }

    void wake_mailboxes() {
        for (auto it = mailboxes.begin(); it != mailboxes.end();) {
            auto mailbox = it->lock();
            if (!mailbox) { it = mailboxes.erase(it); continue; }
            ++it;
            auto work = works.find(mailbox->work);
            int reason = closed ? 3 : work == works.end() ? 0 : stop_reason(work->second);
            if (!reason) continue;
            std::lock_guard<std::mutex> lock(mailbox->mutex);
            if (mailbox->ready || mailbox->closed || mailbox->stop_reason) continue;
            if (work != works.end()) work->second.claimed_stop = reason == 3 ? 1 : reason;
            mailbox->stop_reason = reason;
            mailbox->changed.notify_all();
        }
    }

    // Graph edges do not own memory. JS captures own records, including cycles.
    // Reachability, rather than a reference count, determines execution liveness.
    void refresh() {
        // A claim seals the producer's own derived promises as well as the
        // immediate resource work. A later consumer must not resurrect them.
        std::unordered_map<uint64_t, std::vector<uint64_t>> consumers;
        std::vector<uint64_t> sealed;
        for (const auto &item : works) {
            for (auto dependency : item.second.dependencies)
                consumers[dependency].push_back(item.first);
            if (item.second.claimed_stop) sealed.push_back(item.first);
        }
        while (!sealed.empty()) {
            auto id = sealed.back(); sealed.pop_back();
            const auto &producer = works.at(id);
            for (auto consumer_id : consumers[id]) {
                auto &consumer = works.at(consumer_id);
                if (!consumer.claimed_stop && consumer.task == producer.task) {
                    consumer.claimed_stop = producer.claimed_stop;
                    sealed.push_back(consumer_id);
                }
            }
        }
        std::vector<uint64_t> pending;
        for (auto &item : works) {
            auto task = tasks.find(item.second.task);
            item.second.live = !item.second.claimed_stop && (item.second.task == 0 || task == tasks.end() ||
                (!task->second->completed && task->second->stop.load() == 0));
            if (item.second.live) pending.push_back(item.first);
        }
        while (!pending.empty()) {
            auto id = pending.back(); pending.pop_back();
            auto it = works.find(id);
            if (it == works.end()) continue;
            for (auto dependency : it->second.dependencies) {
                auto found = works.find(dependency);
                if (found != works.end() && !found->second.live && !found->second.claimed_stop) {
                    found->second.live = true;
                    pending.push_back(dependency);
                }
            }
        }
        wake_mailboxes();
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
    if (op == 5) return control->stop_reason(it->second);
    return 0;
}
}
