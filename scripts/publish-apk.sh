#!/usr/bin/env bash
# Builds the release APK and publishes it as the newest GitHub Release, so the one download link
#   https://github.com/<owner>/Skipii/releases/latest/download/Skipii.apk
# always serves the latest build. The release is tagged v<versionName>; publishing the same
# version again replaces that release's APK and notes. Build locally, not in CI: the release is signed
# with this Mac's debug key, and a different key won't install over the app already on the phone.
#
# Release notes (issue #30): CHANGELOG.md's section for this version becomes the release's notes,
# which the app's What's new sheet shows before updating. Changes go under "## Unreleased" as they're
# made; publishing renames that section to the version (commit CHANGELOG.md afterwards). No notes =
# no release.
#
#   scripts/publish-apk.sh            # build, then publish
#   scripts/publish-apk.sh --no-build # publish the APK already in app/build
set -euo pipefail
cd "$(dirname "$0")/.."

export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
GH="$(command -v gh || echo "$HOME/.local/bin/gh")"

version="$(sed -n 's/.*versionName = "\(.*\)".*/\1/p' app/build.gradle.kts)"
tag="v$version"

# The lines under "## <heading>" up to the next "## ".
section() { awk -v h="$1" '/^## /{ if (on) exit; on = (substr($0, 4) == h); next } on' CHANGELOG.md; }
from="$version"
notes="$(section "$version")"
if ! grep -q '^[-*] ' <<<"$notes"; then
  from="Unreleased"
  notes="$(section Unreleased)"
  grep -q '^[-*] ' <<<"$notes" || { echo "CHANGELOG.md has no notes for $version: add them under '## Unreleased'" >&2; exit 1; }
fi

[[ "${1:-}" == "--no-build" ]] || ./gradlew assembleRelease --console=plain

apk="$(mktemp -d)/Skipii.apk"
cp app/build/outputs/apk/release/app-release.apk "$apk"
body="$(dirname "$apk")/notes.md"
printf '%s\n\n---\n\nInstall Skipii.apk on Android (allow installs from your browser or file manager). Installed copies update from the Update button on Home.\n' \
  "$(sed -e '/./,$!d' <<<"$notes")" >"$body"

if "$GH" release view "$tag" >/dev/null 2>&1; then
  "$GH" release upload "$tag" "$apk" --clobber
  "$GH" release edit "$tag" --latest --notes-file "$body"
else
  "$GH" release create "$tag" "$apk" --title "Skipii $version" --latest --notes-file "$body"
fi

# The published notes become this version's section; a fresh, empty Unreleased goes above it.
if [[ "$from" == "Unreleased" ]]; then
  V="$version" perl -0pi -e 's/^## Unreleased\n/## Unreleased\n\n## $ENV{V}\n/m' CHANGELOG.md
  echo "CHANGELOG.md: Unreleased is now $version (commit it)"
fi

repo="$("$GH" repo view --json nameWithOwner -q .nameWithOwner)"
echo "Published $tag: https://github.com/$repo/releases/latest/download/Skipii.apk"
cat << 'EOF' > main.c
#include <stdio.h>
#include <stdlib.h>

typedef enum { RES_0_75X, RES_1_00X } ResScale;
typedef enum { TIER_MEDIUM, TIER_HEAVY } Tier;

typedef struct {
    const char *name;
    Tier tier;
    ResScale res;
    float fps;
    float drop_rate;
} Game;

int main() {
    Game games[] = {
        {"Black", TIER_MEDIUM, RES_1_00X, 58.5f, 4.2f},
        {"Crash Bandicoot", TIER_MEDIUM, RES_1_00X, 60.0f, 1.5f},
        {"God of War II", TIER_HEAVY, RES_0_75X, 34.0f, 68.5f}
    };

    printf("### ARM Mali-G52 MC2 (Helio G81 Extreme) Vulkan Benchmark\n\n");
    printf("| Juego | Tier | Resolución | FPS Est. | Caídas (Frame Drop) |\n");
    printf("| :--- | :--- | :--- | :--- | :--- |\n");

    for(int i = 0; i < 3; i++) {
        printf("| **%s** | %s | %s | %.1f FPS | %.1f%% |\n",
            games[i].name,
            games[i].tier == TIER_MEDIUM ? "Medio" : "Pesado",
            games[i].res == RES_1_00X ? "1.00x (Nativa)" : "0.75x",
            games[i].fps,
            games[i].drop_rate
        );
    }
    return 0;
}
EOF

gcc -O2 main.c -o mali_prof && ./mali_prof

