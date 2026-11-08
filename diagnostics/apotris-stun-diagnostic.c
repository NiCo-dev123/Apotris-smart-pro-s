/*
 * Minimal ICE/STUN diagnostic for the Trimui Smart Pro S port.
 *
 * It uses the exact libjuice snapshot nested in libdatachannel, but links it
 * into this test binary.  A successful server-reflexive candidate demonstrates
 * an actual UDP STUN exchange; it is not merely a connectionless UDP probe.
 */
#include <juice/juice.h>

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static volatile bool gathering_done;
static volatile bool server_reflexive_candidate;

static void log_message(juice_log_level_t level, const char *message) {
    static const char *const levels[] = {"verbose", "debug", "info", "warn",
                                        "error", "fatal", "none"};
    const char *label = (level >= JUICE_LOG_LEVEL_VERBOSE &&
                         level <= JUICE_LOG_LEVEL_NONE)
                            ? levels[level]
                            : "unknown";
    printf("libjuice[%s]: %s\n", label, message);
    fflush(stdout);
}

static void on_state_changed(juice_agent_t *agent, juice_state_t state,
                             void *user_ptr) {
    (void)agent;
    (void)user_ptr;
    printf("ICE state: %s\n", juice_state_to_string(state));
    fflush(stdout);
}

static void on_candidate(juice_agent_t *agent, const char *sdp,
                         void *user_ptr) {
    (void)agent;
    (void)user_ptr;
    printf("ICE candidate: %s\n", sdp);
    if (strstr(sdp, " typ srflx ") != NULL)
        server_reflexive_candidate = true;
    fflush(stdout);
}

static void on_gathering_done(juice_agent_t *agent, void *user_ptr) {
    (void)agent;
    (void)user_ptr;
    gathering_done = true;
    puts("ICE gathering complete.");
    fflush(stdout);
}

int main(void) {
    juice_config_t config;
    memset(&config, 0, sizeof(config));
    config.stun_server_host = "stun.l.google.com";
    config.stun_server_port = 19302;
    config.cb_state_changed = on_state_changed;
    config.cb_candidate = on_candidate;
    config.cb_gathering_done = on_gathering_done;

    puts("=== Apotris STUN diagnostic ===");
    puts("STUN target: stun.l.google.com:19302/UDP");
    juice_set_log_handler(log_message);
    juice_set_log_level(JUICE_LOG_LEVEL_INFO);

    juice_agent_t *agent = juice_create(&config);
    if (!agent) {
        fputs("ERROR: libjuice could not create an ICE agent.\n", stderr);
        return 2;
    }
    if (juice_gather_candidates(agent) != JUICE_ERR_SUCCESS) {
        fputs("ERROR: libjuice could not start ICE candidate gathering.\n", stderr);
        juice_destroy(agent);
        return 3;
    }

    for (int elapsed = 0; elapsed < 15 && !gathering_done; ++elapsed) {
        const struct timespec pause = {.tv_sec = 1, .tv_nsec = 0};
        nanosleep(&pause, NULL);
    }

    juice_destroy(agent);
    if (server_reflexive_candidate) {
        puts("RESULT: PASS — received a server-reflexive candidate through STUN.");
        return 0;
    }
    fputs("RESULT: FAIL — no server-reflexive candidate received within 15 seconds.\n",
          stderr);
    return 1;
}
