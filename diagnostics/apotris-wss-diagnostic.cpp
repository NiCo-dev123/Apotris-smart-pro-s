// Isolated WSS test using the same libdatachannel TLS/WebSocket stack as
// Apotris multiplayer. Certificate verification remains enabled.
#include <rtc/rtc.hpp>

#include <chrono>
#include <condition_variable>
#include <iostream>
#include <mutex>
#include <string>

int main() {
    constexpr auto timeout = std::chrono::seconds(20);
    std::mutex mutex;
    std::condition_variable ready;
    bool complete = false;
    bool opened = false;
    std::string error;

    std::cout << "=== Apotris WSS diagnostic ===\n"
              << "Target: wss://api.apotris.com/ws/<id>/match?turn=1\n"
              << "CA bundle: assets/ssl/cacert.pem\n";

    rtc::InitLogger(rtc::LogLevel::Warning);
    rtc::WebSocketConfiguration configuration;
    configuration.caCertificatePemFile = "assets/ssl/cacert.pem";
    configuration.connectionTimeout = timeout;
    rtc::WebSocket socket(configuration);

    socket.onOpen([&] {
        {
            std::lock_guard<std::mutex> lock(mutex);
            opened = true;
            complete = true;
        }
        std::cout << "WebSocket opened with certificate validation enabled.\n";
        socket.close();
        ready.notify_one();
    });
    socket.onError([&](const std::string &message) {
        {
            std::lock_guard<std::mutex> lock(mutex);
            error = message;
            complete = true;
        }
        std::cerr << "WebSocket error: " << message << '\n';
        ready.notify_one();
    });
    socket.onClosed([&] {
        std::cout << "WebSocket closed.\n";
    });

    try {
        // The route is the current client route used by LinkWebRTC.hpp. The
        // fixed diagnostic identifier never sends a lobby/player message.
        socket.open("wss://api.apotris.com/ws/TSPSDIAG01/match?turn=1");
    } catch (const std::exception &exception) {
        std::cerr << "WebSocket setup exception: " << exception.what() << '\n';
        return 2;
    }

    std::unique_lock<std::mutex> lock(mutex);
    if (!ready.wait_for(lock, timeout + std::chrono::seconds(2), [&] { return complete; })) {
        std::cerr << "RESULT: FAIL — WebSocket timed out.\n";
        socket.close();
        return 1;
    }
    if (!opened) {
        std::cerr << "RESULT: FAIL — WebSocket did not open";
        if (!error.empty())
            std::cerr << " (" << error << ')';
        std::cerr << ".\n";
        return 1;
    }
    std::cout << "RESULT: PASS — WSS signaling endpoint accepted the TLS connection.\n";
    return 0;
}
