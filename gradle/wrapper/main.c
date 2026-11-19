#include "mali_g81_emulator.h"

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
