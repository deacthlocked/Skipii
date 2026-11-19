#ifndef MALI_G81_EMULATOR_H
#define MALI_G81_EMULATOR_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    VULKAN_RES_0_75X = 0,
    VULKAN_RES_1_00X = 1
} VulkanScaleResolution;

typedef enum {
    PROFILE_LIGHT_MEDIUM = 0,
    PROFILE_HEAVY        = 1
} WorkloadTier;

typedef struct {
    char title_name[64];
    WorkloadTier tier;
    VulkanScaleResolution target_res;
    float base_fps;
    float frame_drop_risk_pct;
} GameProfile;

typedef struct {
    char gpu_model[32];
    VulkanScaleResolution current_resolution;
    unsigned int active_threads;
} EmulatorConfig;

/* Prototipos de función */
void init_emulator_config(EmulatorConfig *cfg, VulkanScaleResolution res);
void evaluate_game_performance(const EmulatorConfig *cfg, const GameProfile *game);
void generate_github_markdown_report(const GameProfile *games, size_t count);

#endif /* MALI_G81_EMULATOR_H */
