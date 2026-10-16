#pragma once

#include <cstdint>
#include <deque>
#include <functional>
#include <mutex>
#include <optional>
#include <utility>

namespace multiplayerTransport {

// Callbacks post to the game thread; epochs reject canceled sessions.
// The mailbox may outlive its owner.
template <typename Owner> class SessionEvents {
    using Event = std::function<void(Owner&)>;
    struct Entry {
        uint64_t epoch;
        Event event;
    };
    std::mutex mutex;
    uint64_t epoch = 0;
    std::deque<Entry> pending;

public:
    uint64_t reset() {
        std::lock_guard<std::mutex> guard(mutex);
        pending.clear();
        return ++epoch;
    }

    void post(uint64_t session, Event event) {
        std::lock_guard<std::mutex> guard(mutex);
        if (session == epoch)
            pending.push_back({session, std::move(event)});
    }

    void drain(Owner& owner) {
        // Handlers may reset the mailbox or post more events.
        std::deque<Entry> batch;
        {
            std::lock_guard<std::mutex> guard(mutex);
            batch.swap(pending);
        }
        for (auto& entry : batch) {
            {
                std::lock_guard<std::mutex> guard(mutex);
                if (entry.epoch != epoch)
                    continue;
            }
            entry.event(owner);
        }
    }
};

// Keep reliable controls per peer and only the latest board snapshot.
template <typename Message> class PendingMessages {
    std::deque<Message> reliable;
    std::optional<Message> latestBoard;

public:
    static constexpr size_t limit = 256;

    bool enqueue(Message message, bool board) {
        if (board) {
            latestBoard = std::move(message);
            return true;
        }
        if (reliable.size() >= limit)
            return false;
        reliable.push_back(std::move(message));
        return true;
    }

    size_t size() const { return reliable.size() + bool(latestBoard); }

    template <typename Send> void flush(bool open, Send send) {
        if (!open)
            return;
        while (!reliable.empty()) {
            // Pop only after acceptance; native RTC false means buffered.
            send(reliable.front());
            reliable.pop_front();
        }
        if (latestBoard) {
            send(*latestBoard);
            latestBoard.reset();
        }
    }
};

} // namespace multiplayerTransport
