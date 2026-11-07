# Shared paths and helpers for the ripperdoc CLI. Sourced, not executed.

RIPPERDOC_ROOT="${RIPPERDOC_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
COMPONENTS_JSON="$RIPPERDOC_ROOT/components.json"

# The Steam install is only ever read. Everything is installed into a clone of it.
SOURCE_GAME="${RIPPERDOC_SOURCE_GAME:-$HOME/Library/Application Support/Steam/steamapps/common/Cyberpunk 2077}"
GAME="${RIPPERDOC_GAME:-$HOME/Games/Cyberpunk 2077 Ripperdoc}"
CACHE="${RIPPERDOC_CACHE:-$HOME/Library/Caches/ripperdoc}"
PLAY_LOGS="${RIPPERDOC_LOGS:-$HOME/Library/Logs/Ripperdoc}"

STATE_DIR="$GAME/.ripperdoc"
APP_REL="Cyberpunk2077.app"
BIN_REL="$APP_REL/Contents/MacOS/Cyberpunk2077"

# Paths in the game copy that belong to mods and Ripperdoc. A refresh after a Steam update keeps them.
MOD_PATHS=(
    ".ripperdoc"
    "red4ext"
    "launch_red4ext.sh"
    "engine/tools/scc"
    "engine/tools/libscc_lib.dylib"
    "engine/tools/inputloader.pl"
    "engine/config/platform/mac/input_loader.ini"
    "r6/scripts"
    "r6/tweaks"
    "r6/input"
    "r6/audioware"
    "archive/Mac/mod"
    "bin"
)

if [[ -t 1 ]]; then
    C_RED=$'\033[31m' C_GRN=$'\033[32m' C_YEL=$'\033[33m' C_DIM=$'\033[2m' C_OFF=$'\033[0m'
else
    C_RED="" C_GRN="" C_YEL="" C_DIM="" C_OFF=""
fi

info() { echo "${C_DIM}==>${C_OFF} $*"; }
ok()   { echo "${C_GRN}ok${C_OFF}   $*"; }
warn() { echo "${C_YEL}warn${C_OFF} $*" >&2; }
die()  { echo "${C_RED}error${C_OFF} $*" >&2; exit 1; }

# Everything on the normal install path uses tools every Mac has (plutil, perl, codesign, curl), so players need no
# developer tools. python3, git and dwarfdump are only shims that ask to install the command line tools.

# Mach-O LC_UUID of a binary, uppercase hex without dashes (the same reader RED4ext-macos's installer uses).
macho_uuid() {
    perl -e 'open F,"<",$ARGV[0] or exit 1; binmode F; read F,$h,32; ($m,$ct,$st,$ft,$n)=unpack("V5",$h);
        exit 1 unless $m==0xfeedfacf; $o=32; for(1..$n){seek F,$o,0; read F,$c,8; ($cmd,$sz)=unpack("V2",$c);
        if($cmd==0x1b){read F,$u,16; print uc unpack("H*",$u); exit 0} $o+=$sz} exit 1' "$1" 2>/dev/null
}

pinned_uuid() {
    json_get "game.uuid" | tr -d '-' | tr '[:lower:]' '[:upper:]'
}

# Index of a component in components.json by its id.
component_index() {
    local i n
    n=$(plutil -extract components raw -o - "$COMPONENTS_JSON")
    for ((i = 0; i < n; i++)); do
        [[ "$(plutil -extract "components.$i.id" raw -o - "$COMPONENTS_JSON")" == "$1" ]] && { echo "$i"; return; }
    done
    die "unknown component: $1"
}

# Read one value from components.json, e.g. json_get game.uuid or json_get component.red4ext.sha256.
# Fails (empty output, status 1) when the key is missing; json_has tests for it.
json_get() {
    local path="$1"
    if [[ "$path" == component.* ]]; then
        local rest="${path#component.}"
        local id="${rest%%.*}"
        path="components.$(component_index "$id").${rest#*.}"
    fi
    plutil -extract "$path" raw -o - "$COMPONENTS_JSON" 2>/dev/null
}

json_has() { json_get "$1" >/dev/null; }

component_ids() {
    local i n
    n=$(plutil -extract components raw -o - "$COMPONENTS_JSON")
    for ((i = 0; i < n; i++)); do plutil -extract "components.$i.id" raw -o - "$COMPONENTS_JSON"; done
}

game_running() { pgrep -fq "Cyberpunk2077.app/Contents/MacOS/Cyberpunk2077"; }

require_game_closed() {
    if game_running; then
        die "Cyberpunk 2077 is running. Quit it first."
    fi
}

require_copy() {
    [[ -f "$STATE_DIR/source" ]] || die "No Ripperdoc game copy at $GAME. Run: ripperdoc setup"
}

# Clone a file or folder with APFS clonefile, which costs no disk space until a file changes.
# Refuses to fall back to a real copy (the game is ~75 GB).
clone_tree() {
    local src="$1" dst="$2"
    same_apfs_volume "$src" "$(dirname "$dst")" ||
        die "$(dirname "$dst") is not on the same APFS volume as the game, so a clone would be a full ~75 GB copy."
    cp -Rc "$src" "$dst"
}

same_apfs_volume() {
    local a b
    a=$(stat -f %d "$1") b=$(stat -f %d "$2")
    [[ "$a" == "$b" ]] || return 1
    local out
    out=$(diskutil info "$(df "$1" | awk 'NR==2 {print $1}')" 2>/dev/null) || return 1
    [[ "$out" == *APFS* ]]
}

# Capture codesign output before grepping: with pipefail, `codesign | grep -q` fails when grep exits early (SIGPIPE).
has_red4ext_entitlements() {
    local out
    out=$(codesign -d --entitlements - --xml "$1" 2>/dev/null) || return 1
    [[ "$out" == *allow-unsigned-executable-memory* ]]
}

cdpr_signed() {
    local out
    out=$(codesign -dv --verbose=2 "$1" 2>&1) || return 1   # Authority lines only appear at --verbose=2
    [[ "$out" == *"Authority=Developer ID Application: CD PROJEKT"* ]] && codesign --verify --strict "$1" 2>/dev/null
}
