#include "mali_g81_emulator.h"
#include <arpa/inet.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

int main(void) {
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        perror("socket");
        return 1;
    }

    struct sockaddr_in addr, client_addr;
    socklen_t addr_len = sizeof(client_addr);
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(5005);

    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sock);
        return 1;
    }

    char buf[1024];
    printf("Escuchando en UDP :5005...\n");
    while (1) {
        ssize_t n = recvfrom(sock, buf, sizeof(buf) - 1, 0,
                             (struct sockaddr *)&client_addr, &addr_len);
        if (n > 0) {
            buf[n] = '\0';
            char ip_str[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &client_addr.sin_addr, ip_str, sizeof(ip_str));
            printf("[%s:%d] %s\n", ip_str, ntohs(client_addr.sin_port), buf);
        }
    }

    close(sock);
    return 0;
}

int main(void) {
    EmulatorConfig config;
    init_emulator_config(&config, VULKAN_RES_1_00X);

    GameProfile suite[] = {
        {"Black", PROFILE_LIGHT_MEDIUM, VULKAN_RES_1_00X, 58.5f, 4.2f},
        {"Crash Bandicoot: The Wrath of Cortex", PROFILE_LIGHT_MEDIUM, VULKAN_RES_1_00X, 60.0f, 1.5f},
        {"God of War II", PROFILE_HEAVY, VULKAN_RES_0_75X, 34.0f, 68.5f}
    };

    size_t total_games = sizeof(suite) / sizeof(suite[0]);

    printf("====================================================\n");
    printf("   HELIO G81 EXTREME - VULKAN EMULATION PROFILER\n");
    printf("====================================================\n\n");

    for (size_t i = 0; i < total_games; i++) {
        evaluate_game_performance(&config, &suite[i]);
    }

    generate_github_markdown_report(suite, total_games);

    return 0;
}
gcc -std=c11 -O2 resume_sender.c -o resume_sender_amd64
