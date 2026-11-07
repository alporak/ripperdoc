# Graphics profiles: change the game's graphics settings safely. Sourced by ripperdoc, after common.sh.
#
# The settings live in UserSettings.json, which the Steam game and the Ripperdoc copy share. Before the first change
# Ripperdoc keeps a backup, and `graphics reset` puts it back exactly.

USER_SETTINGS="${RIPPERDOC_USER_SETTINGS:-$HOME/Library/Application Support/CD Projekt Red/Cyberpunk 2077/UserSettings.json}"
SETTINGS_BACKUP="$STATE_DIR/UserSettings.before-ripperdoc.json"
PROFILES="$RIPPERDOC_ROOT/profiles"

# The settings a profile may touch, as "group name"; `graphics show` prints these.
GRAPHICS_KEYS=(
    "/video/display Resolution"
    "/video/display MaximumFPS_OnOff"
    "/video/display MaximumFPS_Value"
    "/graphics/presets ResolutionScaling"
    "/graphics/presets MetalFX"
    "/graphics/presets MetalFX_Sharpness"
    "/graphics/presets MetalFX_FrameGeneration"
    "/graphics/presets DynamicResolutionScaling"
    "/graphics/presets TextureQuality"
    "/graphics/advanced Anisotropy"
    "/graphics/advanced LODPreset"
    "/graphics/advanced CascadedShadowsResolution"
    "/graphics/advanced DistantShadowsResolution"
    "/graphics/advanced VolumetricFogResolution"
    "/graphics/advanced ScreenSpaceReflectionsQuality"
    "/graphics/advanced AmbientOcclusion"
    "/graphics/advanced ContactShadows"
)

us() { perl "$RIPPERDOC_ROOT/lib/usersettings.pl" "$@"; }

backup_settings() {
    [[ -f "$USER_SETTINGS" ]] || die "no game settings at $USER_SETTINGS (start the game once first)"
    mkdir -p "$STATE_DIR"
    if [[ ! -f "$SETTINGS_BACKUP" ]]; then
        cp -p "$USER_SETTINGS" "$SETTINGS_BACKUP"
        info "backed up your settings to $SETTINGS_BACKUP"
    fi
}

cmd_graphics_show() {
    local k
    for k in "${GRAPHICS_KEYS[@]}"; do
        printf '%-48s %s\n' "$k" "$(us get "$USER_SETTINGS" $k 2>/dev/null || echo '-')"
    done
}

# graphics set <group> <name> <value>
cmd_graphics_set() {
    [[ $# -eq 3 ]] || die "usage: ripperdoc graphics set <group> <name> <value>   (see: ripperdoc graphics show)"
    require_game_closed   # the game writes its settings back when it quits
    backup_settings
    us set "$USER_SETTINGS" "$1" "$2" "$3"
    ok "$2 = $3"
}

# A profile is a text file of lines "setting <group> <name> <value>" ('#' starts a comment).
cmd_graphics_apply() {
    local profile="${1:-}" file kind group name value n=0
    [[ -n "$profile" ]] || die "usage: ripperdoc graphics apply <profile>   (profiles: $(ls "$PROFILES" 2>/dev/null | sed 's/\.conf$//' | tr '\n' ' '))"
    file="$profile"
    [[ -f "$file" ]] || file="$PROFILES/$profile.conf"
    [[ -f "$file" ]] || die "no profile $profile"
    require_game_closed
    backup_settings
    # Check every line first, so a bad profile changes nothing.
    local tmp
    tmp=$(mktemp)
    cp -p "$USER_SETTINGS" "$tmp"
    while read -r kind group name value; do
        [[ -z "$kind" || "$kind" == \#* ]] && continue
        [[ "$kind" == setting ]] || { rm -f "$tmp"; die "unknown line in $file: $kind $group $name $value"; }
        us set "$tmp" "$group" "$name" "$value" || { rm -f "$tmp"; die "profile $profile: cannot set $name to $value"; }
        n=$((n + 1))
    done <"$file"
    mv "$tmp" "$USER_SETTINGS"
    ok "applied $(basename "$file" .conf): $n setting(s)"
}

cmd_graphics_reset() {
    require_game_closed
    [[ -f "$SETTINGS_BACKUP" ]] || die "nothing to reset: Ripperdoc never changed your graphics settings"
    cp -p "$SETTINGS_BACKUP" "$USER_SETTINGS"
    ok "restored the settings you had before Ripperdoc changed them"
}

cmd_graphics() {
    case "${1:-show}" in
        show) shift || true; cmd_graphics_show ;;
        set) shift; cmd_graphics_set "$@" ;;
        apply) shift; cmd_graphics_apply "$@" ;;
        reset) shift; cmd_graphics_reset ;;
        *) die "usage: ripperdoc graphics show | set <group> <name> <value> | apply <profile> | reset" ;;
    esac
}
