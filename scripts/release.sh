#!/usr/bin/env bash
# Ripperdoc releases, in two steps, so what gets published is exactly what was tested:
#
#   scripts/release.sh build 0.1.0     build into release/0.1.0/: the prebuilt bundles of the source components
#                                       (Mod Settings, CET, Audioware), pinned in components.json; Ripperdoc-0.1.0.zip
#                                       (the app, carrying the CLI and that components.json); SHA256SUMS; the notes.
#                                       Then test them (RIPPERDOC_ASSET_BASE=file://.../release/0.1.0) and commit
#                                       components.json.
#   scripts/release.sh publish 0.1.0   check that the committed pins match those files, tag v0.1.0, push, and
#                                       create the GitHub release with them.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STEP="${1:?usage: scripts/release.sh build|publish <version>}"
VERSION="${2:?usage: scripts/release.sh build|publish <version>}"
TAG="v$VERSION"
REPO_SLUG="alporak/ripperdoc"
OUT="$ROOT/release/$VERSION"
BUILT=(modsettings cet audioware)

cd "$ROOT"
[[ -z "$(git status --porcelain)" ]] || { echo "commit or stash your changes first" >&2; exit 1; }

if [[ "$STEP" == publish ]]; then
    git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "tag $TAG already exists" >&2; exit 1; }
    (cd "$OUT" && shasum -a 256 -c SHA256SUMS >/dev/null) || { echo "release/$VERSION does not match its SHA256SUMS" >&2; exit 1; }
    for id in "${BUILT[@]}"; do
        i=$(bash -c "source lib/common.sh; component_index $id")
        url=$(plutil -extract "components.$i.prebuilt_url" raw -o - components.json)
        sha=$(plutil -extract "components.$i.prebuilt_sha256" raw -o - components.json)
        [[ "$url" == "https://github.com/$REPO_SLUG/releases/download/$TAG/"* ]] || { echo "$id is not pinned to $TAG" >&2; exit 1; }
        [[ "$(shasum -a 256 "$OUT/$(basename "$url")" | cut -d' ' -f1)" == "$sha" ]] || { echo "$id pin does not match its file" >&2; exit 1; }
    done
    unzip -p "$OUT/Ripperdoc-$VERSION.zip" Ripperdoc.app/Contents/Resources/ripperdoc/components.json | cmp -s - components.json ||
        { echo "the app zip carries a different components.json than the committed one" >&2; exit 1; }
    git tag -a "$TAG" -m "Ripperdoc $VERSION"
    git push -q origin HEAD "$TAG"
    gh release create "$TAG" --repo "$REPO_SLUG" --title "Ripperdoc $VERSION" --notes-file "$OUT/NOTES.md" \
        "$OUT"/*.zip "$OUT/SHA256SUMS"
    echo "published https://github.com/$REPO_SLUG/releases/tag/$TAG"
    exit 0
fi
[[ "$STEP" == build ]] || { echo "usage: scripts/release.sh build|publish <version>" >&2; exit 1; }
rm -rf "$OUT" && mkdir -p "$OUT"

# 1. Bundles, built from the pinned sources (and Ripperdoc's patches).
for id in "${BUILT[@]}"; do
    stage=$(mktemp -d)
    ./ripperdoc build-bundle "$id" "$stage"
    while IFS= read -r f; do codesign -f -s - "$f" 2>/dev/null; done < <(find "$stage" -name '*.dylib')
    file="$id-$(plutil -extract "components.$(bash -c "source lib/common.sh; component_index $id").version" raw -o - components.json | tr '+' '-')-macos-arm64.zip"
    (cd "$stage" && ditto -c -k --norsrc . "$OUT/$file")
    rm -rf "$stage"
    sha=$(shasum -a 256 "$OUT/$file" | cut -d' ' -f1)
    python3 - "$id" "https://github.com/$REPO_SLUG/releases/download/$TAG/$file" "$sha" <<'PY'
import json, sys
p = "components.json"
d = json.load(open(p))
c = next(c for c in d["components"] if c["id"] == sys.argv[1])
c["prebuilt_url"], c["prebuilt_sha256"] = sys.argv[2], sys.argv[3]
json.dump(d, open(p, "w"), indent=2)
open(p, "a").write("\n")
PY
    echo "bundle $file $sha"
done

# 2. The app, carrying the updated components.json.
app/build-app.sh >/dev/null
(cd app/build && ditto -c -k --keepParent --norsrc Ripperdoc.app "$OUT/Ripperdoc-$VERSION.zip")

# 3. Checksums and notes.
(cd "$OUT" && shasum -a 256 *.zip > SHA256SUMS)
sed "s/@VERSION@/$VERSION/g; s#@REPO@#$REPO_SLUG#g" docs/RELEASE_NOTES.md > "$OUT/NOTES.md"
cat "$OUT/SHA256SUMS"
echo "release files in $OUT"

echo "next: test with RIPPERDOC_ASSET_BASE=file://$OUT, commit components.json, then: scripts/release.sh publish $VERSION"
