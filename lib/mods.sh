# Installing Windows-layout mods into the game copy. Sourced by ripperdoc, after common.sh.
#
# A mod is unpacked, each file's Windows path is mapped to where the Mac frameworks read it, and the list of installed files
# is kept in .ripperdoc/mods/<name>.files, so `mod remove` takes exactly those files out again.

MODS_DIR="$STATE_DIR/mods"

# Map one path inside a mod (Windows layout) to its path in the game copy. Prints nothing for files that have no Mac place.
mac_path() {
    local p="$1"
    case "$p" in
        archive/pc/mod/*) echo "archive/Mac/mod/${p#archive/pc/mod/}" ;;
        archive/Mac/mod/*) echo "$p" ;;
        r6/scripts/* | r6/tweaks/* | r6/input/* | r6/audioware/*) echo "$p" ;;
        bin/x64/plugins/cyber_engine_tweaks/mods/*)
            echo "red4ext/plugins/cyber_engine_tweaks/mods/${p#bin/x64/plugins/cyber_engine_tweaks/mods/}" ;;
        red4ext/plugins/*.dylib | red4ext/plugins/*/Scripts/* | red4ext/plugins/*/*.reds) echo "$p" ;;
        *) ;;
    esac
}

# Why a file was skipped, for the files mac_path has no place for.
skip_reason() {
    case "$1" in
        *.dll) echo "Windows plugin (.dll); it needs a macOS .dylib build" ;;
        mods/*) echo "REDmod layout is not supported on the Mac" ;;
        archive/pc/content/*) echo "replaces official game archives, not supported" ;;
        *) echo "not a known mod folder" ;;
    esac
}

# The mod root inside an unpacked tree: the folder that holds archive/, r6/, bin/ or red4ext/ (mods often wrap it in one
# extra folder).
mod_root() {
    local dir="$1" sub
    for sub in "$dir" "$dir"/*/; do
        sub="${sub%/}"
        if [[ -d "$sub/archive" || -d "$sub/r6" || -d "$sub/bin" || -d "$sub/red4ext" ]]; then
            echo "$sub"
            return
        fi
    done
    die "no archive/, r6/, bin/ or red4ext/ folder in this mod; it does not look like a Cyberpunk 2077 mod"
}

# "Project Capricorn 36701 1.1 2026-11-01T20-10Z MTheTjwGN.rar" -> "Project-Capricorn" (Nexus names: title, id, version, ...)
mod_name_from() {
    local base
    base=$(basename "$1")
    base="${base%.*}"
    base=$(sed -E 's/ [0-9].*$//; s/[^A-Za-z0-9._-]+/-/g; s/^-+|-+$//g' <<<"$base")
    echo "${base:-mod}"
}

cmd_mod_add() {
    require_game_closed
    require_copy
    local src="" name="" force=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) name="$2"; shift 2 ;;
            --force) force=1; shift ;;
            *) src="$1"; shift ;;
        esac
    done
    [[ -e "$src" ]] || die "usage: ripperdoc mod add <mod.zip|.rar|.7z|folder> [--name NAME] [--force]"
    [[ -n "$name" ]] || name=$(mod_name_from "$src")
    [[ ! -f "$MODS_DIR/$name.files" ]] || die "a mod named $name is installed; remove it first: ripperdoc mod remove $name"

    local tmp root
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/ripperdoc-mod.XXXXXX")
    # A RETURN trap stays set after this function returns; clear it the first time it fires.
    trap 'rm -rf "${tmp:-}"; trap - RETURN' RETURN
    if [[ -d "$src" ]]; then
        ditto "$src" "$tmp/x"
    else
        mkdir -p "$tmp/x"
        tar -xf "$src" -C "$tmp/x" || die "could not unpack $src"
    fi
    root=$(mod_root "$tmp/x")

    # Plan every file first, so a conflict changes nothing.
    local plan="$tmp/plan" rel dst skipped=0
    : >"$plan"
    while IFS= read -r rel; do
        dst=$(mac_path "$rel")
        if [[ -z "$dst" ]]; then
            warn "skipping $rel: $(skip_reason "$rel")"
            skipped=$((skipped + 1))
            continue
        fi
        if [[ -e "$GAME/$dst" && $force -eq 0 ]]; then
            die "$dst already exists (from another mod or framework); nothing installed. Use --force to overwrite it."
        fi
        printf '%s\t%s\n' "$rel" "$dst" >>"$plan"
    done < <(cd "$root" && find . -type f ! -name '.DS_Store' | sed 's#^\./##' | sort)
    [[ -s "$plan" ]] || die "nothing in this mod can be installed on the Mac"

    mkdir -p "$MODS_DIR"
    while IFS=$'\t' read -r rel dst; do
        mkdir -p "$(dirname "$GAME/$dst")"
        cp -p "$root/$rel" "$GAME/$dst"
        xattr -d com.apple.quarantine "$GAME/$dst" 2>/dev/null || true
        [[ "$dst" == *.dylib ]] && codesign -f -s - "$GAME/$dst" 2>/dev/null
        echo "$dst"
    done <"$plan" >"$MODS_DIR/$name.files"
    local note=""
    [[ $skipped -gt 0 ]] && note=", $skipped skipped"
    ok "$name: $(wc -l <"$MODS_DIR/$name.files" | tr -d ' ') file(s) installed$note"
    sed 's/^/     /' "$MODS_DIR/$name.files"
}

cmd_mod_remove() {
    require_game_closed
    require_copy
    local name="${1:-}" f
    [[ -n "$name" && -f "$MODS_DIR/$name.files" ]] || die "no installed mod named '$name' (see: ripperdoc mod list)"
    while IFS= read -r f; do
        rm -f "$GAME/$f"
        # Remove folders the mod created and left empty, never the framework folders themselves.
        rmdir -p "$(dirname "$GAME/$f")" 2>/dev/null || true
    done <"$MODS_DIR/$name.files"
    mkdir -p "$GAME/r6/scripts" "$GAME/r6/tweaks" "$GAME/r6/input" "$GAME/archive/Mac/mod"
    rm -f "$MODS_DIR/$name.files"
    ok "removed $name"
}

cmd_mod_list() {
    require_copy
    local f
    for f in "$MODS_DIR"/*.files; do
        [[ -f "$f" ]] || { info "no mods installed"; return; }
        echo "$(basename "$f" .files) ($(wc -l <"$f" | tr -d ' ') files)"
    done
}

cmd_mod() {
    case "${1:-}" in
        add) shift; cmd_mod_add "$@" ;;
        remove) shift; cmd_mod_remove "$@" ;;
        list) shift; cmd_mod_list "$@" ;;
        *) die "usage: ripperdoc mod add <file> | mod remove <name> | mod list" ;;
    esac
}
