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

    struct sockaddr_in dest;
    memset(&dest, 0, sizeof(dest));
    dest.sin_family = AF_INET;
    dest.sin_port = htons(50005);
    inet_pton(AF_INET, "192.168.1.50", &dest.sin_addr);

    const char *msg = "YB_EMU|t=0.016|val=42.75";
    sendto(sock, msg, strlen(msg), 0, (struct sockaddr *)&dest, sizeof(dest));

    close(sock);
    return 0;
}

void init_emulator_config(EmulatorConfig *cfg, VulkanScaleResolution res) {
    snprintf(cfg->gpu_model, sizeof(cfg->gpu_model), "ARM Mali-G52 MC2");
    cfg->current_resolution = res;
    cfg->active_threads = 8; // 2x Cortex-A75 + 6x Cortex-A55
}

void evaluate_game_performance(const EmulatorConfig *cfg, const GameProfile *game) {
    printf("[Vulkan API | %s] Evaluando: %s...\n", cfg->gpu_model, game->title_name);
    
    const char *res_str = (game->target_res == VULKAN_RES_0_75X) ? "0.75x" : "1.00x (Nativa)";
    
    if (game->tier == PROFILE_LIGHT_MEDIUM) {
        printf(" -> Estado: ESTABLE / FLUIDO\n");
        printf(" -> Resolución recomendada: %s\n", res_str);
        printf(" -> FPS estimado: %.1f FPS\n", game->base_fps);
        printf(" -> Riesgo de caídas de frames: %.1f%%\n\n", game->frame_drop_risk_pct);
    } else {
        printf(" -> Estado: INESTABLE (Caídas de frames notables)\n");
        printf(" -> Resolución recomendada: 0.75x (Sub-sampling agresivo requerido)\n");
        printf(" -> FPS estimado: %.1f FPS (con caídas severas en escenas complejas)\n", game->base_fps);
        printf(" -> Riesgo de caídas de frames: %.1f%%\n\n", game->frame_drop_risk_pct);
    }
}

void generate_github_markdown_report(const GameProfile *games, size_t count) {
    printf("### Reporte Automático de Benchmark para GitHub\n\n");
    printf("| Título | Carga / Tier | Res. Recomendada | FPS Promedio | Rango de Caídas |\n");
    printf("| :--- | :--- | :--- | :--- | :--- |\n");
    
    for (size_t i = 0; i < count; i++) {
        const char *tier_str = (games[i].tier == PROFILE_LIGHT_MEDIUM) ? "Ligero / Medio" : "Exigente / Pesado";
        const char *res_str  = (games[i].target_res == VULKAN_RES_0_75X) ? "0.75x" : "1.00x";
        
        printf("| **%s** | %s | %s | %.1f FPS | %.0f%% |\n",
               games[i].title_name, tier_str, res_str, games[i].base_fps, games[i].frame_drop_risk_pct);
    }
    printf("\n");
}
gcc -O2 -Wall listener_udp.c -o listener_udp
./listener_udp
