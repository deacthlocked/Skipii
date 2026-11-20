#define _FILE_OFFSET_BITS 64
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <errno.h>

#define CHUNK_SIZE (4 * 1024 * 1024) /* 4 MB */

static uint64_t htonll_u64(uint64_t val) {
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    return (((uint64_t)htonl((uint32_t)(val & 0xFFFFFFFFULL))) << 32) |
           htonl((uint32_t)(val >> 32));
#else
    return val;
#endif
}

static int send_all(int fd, const void *buf, size_t len) {
    const uint8_t *p = (const uint8_t *)buf;
    size_t sent = 0;
    while (sent < len) {
        ssize_t n = send(fd, p + sent, len - sent, 0);
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (n == 0) return -1;
        sent += (size_t)n;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Uso: %s <archivo_grande> <host_o_ip> <puerto>\n", argv[0]);
        return 1;
    }

    const char *path = argv[1];
    const char *host = argv[2];
    const char *port = argv[3];

    struct stat st;
    if (stat(path, &st) != 0) {
        perror("stat");
        return 1;
    }
    uint64_t total_size = (uint64_t)st.st_size;

    FILE *fp = fopen(path, "rb");
    if (!fp) {
        perror("fopen");
        return 1;
    }

    struct addrinfo hints = {0}, *res = NULL;
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    if (getaddrinfo(host, port, &hints, &res) != 0 || !res) {
        perror("getaddrinfo");
        fclose(fp);
        return 1;
    }

    int sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (sock < 0 || connect(sock, res->ai_addr, res->ai_addrlen) < 0) {
        perror("socket/connect");
        freeaddrinfo(res);
        if (sock >= 0) close(sock);
        fclose(fp);
        return 1;
    }
    freeaddrinfo(res);

    uint64_t net_size = htonll_u64(total_size);
    if (send_all(sock, &net_size, sizeof(net_size)) != 0) {
        perror("send header");
        close(sock);
        fclose(fp);
        return 1;
    }

    uint8_t *buf = malloc(CHUNK_SIZE);
    if (!buf) {
        perror("malloc");
        close(sock);
        fclose(fp);
        return 1;
    }

    uint64_t sent_total = 0;
    time_t start_t = time(NULL);

    while (sent_total < total_size) {
        size_t nread = fread(buf, 1, CHUNK_SIZE, fp);
        if (nread == 0) {
            if (ferror(fp)) perror("fread");
            break;
        }
        if (send_all(sock, buf, nread) != 0) {
            perror("send_all");
            break;
        }
        sent_total += (uint64_t)nread;

        time_t now = time(NULL);
        double elapsed = difftime(now, start_t);
        if (elapsed > 0.0) {
            double mbps = ((double)sent_total * 8.0) / (elapsed * 1e6);
            double pct = ((double)sent_total / (double)total_size) * 100.0;
            fprintf(stdout, "\rProgreso: %.4f%% (%llu / %llu bytes) | %.2f Mbps",
                    pct, (unsigned long long)sent_total,
                    (unsigned long long)total_size, mbps);
            fflush(stdout);
        }
    }
    printf("\nFinalizado: %llu bytes enviados.\n", (unsigned long long)sent_total);

    free(buf);
    close(sock);
    fclose(fp);
    return (sent_total == total_size) ? 0 : 1;
}
sudo apt update && sudo apt install -y gcc-aarch64-linux-gnu
aarch64-linux-gnu-gcc -std=c11 -O2 sender_50tb.c -o sender_50tb_arm64
export NDK=/ruta/al/android-ndk
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
$TOOLCHAIN/aarch64-linux-android28-clang -std=c11 -O2 sender_50tb.c -o sender_50tb_android_arm64
#define _FILE_OFFSET_BITS 64
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>

#define CHUNK_SIZE (4 * 1024 * 1024)

static uint64_t htonll_u64(uint64_t val) {
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    return (((uint64_t)htonl((uint32_t)(val & 0xFFFFFFFFULL))) << 32) |
           htonl((uint32_t)(val >> 32));
#else
    return val;
#endif
}

static uint64_t ntohll_u64(uint64_t val) {
    return htonll_u64(val);
}

static int send_all(int fd, const void *buf, size_t len) {
    const uint8_t *p = (const uint8_t *)buf;
    size_t sent = 0;
    while (sent < len) {
        ssize_t n = send(fd, p + sent, len - sent, 0);
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (n == 0) return -1;
        sent += (size_t)n;
    }
    return 0;
}

static int recv_all(int fd, void *buf, size_t len) {
    uint8_t *p = (uint8_t *)buf;
    size_t got = 0;
    while (got < len) {
        ssize_t n = recv(fd, p + got, len - got, 0);
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (n == 0) return -1;
        got += (size_t)n;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Uso: %s <archivo> <host_ip_estatica> <puerto>\n", argv[0]);
        return 1;
    }

    const char *path = argv[1];
    const char *host = argv[2];
    const char *port = argv[3];

    struct stat st;
    if (stat(path, &st) != 0) {
        perror("stat");
        return 1;
    }
    uint64_t total_size = (uint64_t)st.st_size;

    FILE *fp = fopen(path, "rb");
    if (!fp) {
        perror("fopen");
        return 1;
    }

    struct addrinfo hints = {0}, *res = NULL;
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    if (getaddrinfo(host, port, &hints, &res) != 0 || !res) {
        perror("getaddrinfo");
        fclose(fp);
        return 1;
    }

    int sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (sock < 0 || connect(sock, res->ai_addr, res->ai_addrlen) < 0) {
        perror("socket/connect");
        freeaddrinfo(res);
        if (sock >= 0) close(sock);
        fclose(fp);
        return 1;
    }
    freeaddrinfo(res);

    /* 1. Enviar tamaño total del archivo */
    uint64_t net_total = htonll_u64(total_size);
    if (send_all(sock, &net_total, sizeof(net_total)) != 0) {
        perror("send total_size");
        close(sock);
        fclose(fp);
        return 1;
    }

    /* 2. Recibir offset solicitado por el receptor */
    uint64_t net_offset = 0;
    if (recv_all(sock, &net_offset, sizeof(net_offset)) != 0) {
        perror("recv offset");
        close(sock);
        fclose(fp);
        return 1;
    }
    uint64_t offset = ntohll_u64(net_offset);
    if (offset > total_size) {
        fprintf(stderr, "Offset invalido (%llu > %llu)\n",
                (unsigned long long)offset, (unsigned long long)total_size);
        close(sock);
        fclose(fp);
        return 1;
    }

    if (fseeko(fp, (off_t)offset, SEEK_SET) != 0) {
        perror("fseeko");
        close(sock);
        fclose(fp);
        return 1;
    }

    /* 3. Transmitir desde offset */
    uint8_t *buf = malloc(CHUNK_SIZE);
    if (!buf) {
        perror("malloc");
        close(sock);
        fclose(fp);
        return 1;
    }

    uint64_t sent_from_offset = 0;
    size_t nread;
    while ((nread = fread(buf, 1, CHUNK_SIZE, fp)) > 0) {
        if (send_all(sock, buf, nread) != 0) {
            perror("send_all");
            break;
        }
        sent_from_offset += (uint64_t)nread;
    }

    printf("Reanudado desde %llu | Enviados en esta sesion: %llu\n",
           (unsigned long long)offset, (unsigned long long)sent_from_offset);

    free(buf);
    close(sock);
    fclose(fp);
    return 0;
}
gcc -std=c11 -O2 resume_sender.c -o resume_sender_amd64
