# Benchmarks: run the game's built-in benchmark and record FPS and memory. Sourced by ripperdoc, after graphics.sh.
#
# A run launches the game copy in benchmark mode with the frame cap off (restored afterwards), samples the game's
# memory footprint and the system's swap use every few seconds, waits for the benchmark's results file, and saves a
# record with the graphics settings used to ~/Library/Logs/Ripperdoc/bench/.

BENCH_DIR="$PLAY_LOGS/bench"
BENCH_ARGS=(-benchmark)
BENCH_TIMEOUT=480          # seconds; the benchmark itself takes about two minutes after loading

swap_used_mb() { sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9.]+)M.*/\1/'; }

footprint_mb() {
    local out
    out=$(footprint "$1" 2>/dev/null) || return 0
    perl -ne 'if (/phys_footprint:\s*([\d.]+)\s*([KMG]B)/) { my %m = (KB => 1/1024, MB => 1, GB => 1024); printf "%.0f\n", $1 * $m{$2}; exit }' <<<"$out"
}

# The game writes each run to benchmarkResults/benchmark_<time>/ (summary.json and frames.csv), next to its settings.
BENCH_RESULTS="$(dirname "$USER_SETTINGS")/benchmarkResults"

# The summary.json of the first benchmark run that finished after a marker file.
newest_result() {
    find "$BENCH_RESULTS" -maxdepth 2 -name summary.json -newer "$1" 2>/dev/null | head -1
}

# Numbers from a run: summary.json (FPS, settings) and frames.csv (frame times, memory).
bench_numbers() {
    local summary="$1"
    perl -MJSON::PP -e '
        my $d = decode_json(do { local $/; open my $f, "<", $ARGV[0] or die; <$f> })->{Data};
        printf "average_fps: %.1f\nmin_fps: %.1f\nmax_fps: %.1f\n", @$d{qw(averageFps minFps maxFps)};
        open my $c, "<", $ARGV[1] or exit;
        <$c>;
        my (@ft, $cpu, $gpu);
        while (<$c>) {
            my @v = split /,\s*/;
            push @ft, $v[1];
            $cpu = $v[3] if !defined $cpu || $v[3] > $cpu;
            $gpu = $v[4] if !defined $gpu || $v[4] > $gpu;
        }
        @ft = sort { $b <=> $a } @ft;
        my $n = int(@ft / 100) || 1;
        my $sum = 0; $sum += $_ for @ft[0 .. $n - 1];
        printf "one_percent_low_fps: %.1f\nworst_frame_ms: %.1f\npeak_cpu_memory_mb: %.0f\npeak_gpu_memory_mb: %.0f\n",
            1000 / ($sum / $n), $ft[0], $cpu, $gpu;
    ' "$summary" "$(dirname "$summary")/frames.csv"
}

cmd_bench() {
    local label="${1:-run}" marker log game_pid result peak=0 swap_start swap_peak t=0 fp sw cap_was record
    require_game_closed
    require_copy
    backup_settings
    mkdir -p "$BENCH_DIR"
    marker=$(mktemp "$BENCH_DIR/.start.XXXXXX")
    log="$BENCH_DIR/$(date +%Y-%m-%d-%H%M%S)-$label.log"

    # Uncapped, so the headroom above the target is visible. The cap comes back however the run ends: an EXIT trap,
    # since die() exits the script (a RETURN trap would be skipped). The game writes its settings back when it quits,
    # so the cap is restored after the game has exited.
    cap_was=$(us get "$USER_SETTINGS" /video/display MaximumFPS_OnOff)
    us set "$USER_SETTINGS" /video/display MaximumFPS_OnOff false
    BENCH_CAP_WAS="$cap_was" BENCH_MARKER="$marker"
    trap 'us set "$USER_SETTINGS" /video/display MaximumFPS_OnOff "$BENCH_CAP_WAS" 2>/dev/null; rm -f "$BENCH_MARKER"' EXIT

    info "benchmark '$label': launching (about 3 minutes; don't touch the game)"
    "$GAME/launch_red4ext.sh" "${BENCH_ARGS[@]}" >"$log" 2>&1 &
    while [[ -z "${game_pid:-}" && $t -lt 120 ]]; do
        game_pid=$(pgrep -f "$GAME/$BIN_REL" | head -1 || true)
        sleep 2; t=$((t + 2))
    done
    [[ -n "${game_pid:-}" ]] || die "the game did not start; see $log"

    swap_start=$(swap_used_mb); swap_peak=$swap_start
    while kill -0 "$game_pid" 2>/dev/null && [[ $t -lt $BENCH_TIMEOUT ]]; do
        fp=$(footprint_mb "$game_pid"); [[ -n "$fp" && "$fp" -gt "$peak" ]] && peak=$fp
        sw=$(swap_used_mb); perl -e 'exit !($ARGV[0] > $ARGV[1])' "$sw" "$swap_peak" && swap_peak=$sw
        result=$(newest_result "$marker")
        [[ -n "$result" ]] && break
        sleep 5; t=$((t + 5))
    done
    if kill -0 "$game_pid" 2>/dev/null; then
        sleep 3
        kill -TERM "$game_pid" 2>/dev/null || true
        while kill -0 "$game_pid" 2>/dev/null; do sleep 1; done
    fi
    # The game writes the results and quits within the same few seconds, often between two polls.
    [[ -n "$result" ]] || { sleep 2; result=$(newest_result "$marker"); }
    [[ -n "$result" ]] || die "no benchmark results after ${t}s; see $log"

    record="${log%.log}.txt"
    {
        echo "label: $label"
        echo "results: $result"
        bench_numbers "$result"
        echo "peak_footprint_mb: $peak"
        printf 'swap_growth_mb: %.0f\n' "$(perl -e 'print $ARGV[0] - $ARGV[1]' "$swap_peak" "$swap_start")"
        echo "settings:"
        cmd_graphics_show | sed 's/^/  /'
    } >"$record"
    ok "benchmark '$label' done"
    grep -E '^(average_fps|one_percent_low_fps|peak_footprint_mb|swap_growth_mb):' "$record"
}

cmd_bench_list() {
    local f
    for f in "$BENCH_DIR"/*.txt; do
        [[ -f "$f" ]] || { info "no benchmark runs yet"; return; }
        printf '%-26s avg %6s  1%%low %6s  footprint %6s MB  swap +%s MB\n' "$(sed -n 's/^label: //p' "$f")" \
            "$(sed -n 's/^average_fps: //p' "$f")" "$(sed -n 's/^one_percent_low_fps: //p' "$f")" \
            "$(sed -n 's/^peak_footprint_mb: //p' "$f")" "$(sed -n 's/^swap_growth_mb: //p' "$f")"
    done
}
