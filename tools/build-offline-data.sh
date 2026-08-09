#!/usr/bin/env bash
# Build Sylph's offline map data set: basemap tiles, glyphs, sprites, styles,
# a routing graph, and a geocoder index. Idempotent -- each stage skips if its
# output already exists. Re-run with FORCE=1 to rebuild everything.
#
#   ./tools/build-offline-data.sh
#   BBOX="30.6,29.6,32.0,30.6" REGION=egypt ./tools/build-offline-data.sh
set -euo pipefail

# -- Config -------------------------------------------------------------------
BBOX="${BBOX:-30.6,29.6,32.0,30.6}"                  # min_lon,min_lat,max_lon,max_lat -- greater Cairo
MAXZOOM="${MAXZOOM:-14}"
REGION="${REGION:-egypt}"
PBF_URL="${PBF_URL:-https://download.geofabrik.de/africa/egypt-latest.osm.pbf}"
PHOTON_CC="${PHOTON_CC:-eg}"
# 0.7.4, NOT 1.x: the prebuilt indexes on graphhopper are the Elasticsearch
# layout (photon_data/elasticsearch), and Photon 1.x switched to OpenSearch --
# it rejects this index with "OpenSearch database not found". 0.7.x also runs on
# Java 17; 1.x needs Java 21.
PHOTON_VER="${PHOTON_VER:-0.7.4}"
PMTILES_VER="${PMTILES_VER:-1.31.2}"

DATA_DIR="${SYLPH_MAP_DIR:-$HOME/.local/share/Sylph/Sylph/maps}"
WORK_DIR="${WORK_DIR:-$HOME/.cache/sylph-offline-build}"
OSRM_DIR="$WORK_DIR/osrm"
PHOTON_DIR="$WORK_DIR/photon"
BIN_DIR="$WORK_DIR/bin"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
have() { [ -e "$1" ] && [ -z "${FORCE:-}" ]; }
# Geofabrik and graphhopper both reset long transfers; resume and retry.
fetch() { curl -fSL --progress-bar --retry 8 --retry-delay 5 --retry-all-errors -C - "$1" -o "$2"; }

# node lives under nvm here and is not on a non-interactive PATH
if ! command -v npx >/dev/null 2>&1; then
    NVM_NODE=$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1 || true)
    [ -n "$NVM_NODE" ] && PATH="$NVM_NODE:$PATH" && export PATH
fi
for t in curl git docker java python3 npx; do
    command -v "$t" >/dev/null 2>&1 || { echo "missing required tool: $t" >&2; exit 1; }
done

mkdir -p "$DATA_DIR" "$WORK_DIR" "$OSRM_DIR" "$PHOTON_DIR" "$BIN_DIR"

# -- 1. Basemap: extract our bbox from the Protomaps planet --------------------
# The planet is ~128 GB but pmtiles reads it over HTTP range requests, so we
# only download the tiles inside BBOX.
if ! have "$BIN_DIR/pmtiles"; then
    log "Fetching go-pmtiles $PMTILES_VER"
    curl -fsSL "https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_VER}/go-pmtiles_${PMTILES_VER}_Linux_x86_64.tar.gz" \
        | tar -xz -C "$BIN_DIR" pmtiles
fi

if ! have "$DATA_DIR/region.pmtiles"; then
    # build.protomaps.com publishes every ~3 days; walk back to the newest build.
    PM_DATE=""
    for i in $(seq 0 15); do
        d=$(date -u -d "-$i day" +%Y%m%d)
        if curl -fsI --max-time 20 "https://build.protomaps.com/$d.pmtiles" >/dev/null 2>&1; then
            PM_DATE="$d"; break
        fi
    done
    [ -n "$PM_DATE" ] || { echo "No Protomaps planet build found in the last 15 days" >&2; exit 1; }

    log "Extracting basemap from planet $PM_DATE (bbox $BBOX, maxzoom $MAXZOOM)"
    "$BIN_DIR/pmtiles" extract "https://build.protomaps.com/$PM_DATE.pmtiles" \
        "$DATA_DIR/region.pmtiles" \
        --bbox="$BBOX" --maxzoom="$MAXZOOM" --download-threads=8
    echo "$PM_DATE" > "$DATA_DIR/.pmtiles-build"
fi

# -- 2. Glyphs + sprites ------------------------------------------------------
# MapQuickItem passes devicePixelRatio into Settings, so the @2x sprites are
# required on a HiDPI panel.
# Only the three fontstacks the style actually references -- the full fonts/
# tree carries Devanagari and other scripts we never ask for.
FONTSTACKS=("Noto Sans Regular" "Noto Sans Medium" "Noto Sans Italic")

if ! have "$DATA_DIR/fonts"; then
    log "Fetching glyphs + sprites (protomaps/basemaps-assets)"
    rm -rf "$WORK_DIR/assets"
    git clone --depth 1 --filter=blob:none --sparse \
        https://github.com/protomaps/basemaps-assets.git "$WORK_DIR/assets"
    ( cd "$WORK_DIR/assets" && git sparse-checkout set sprites/v4 \
        "fonts/${FONTSTACKS[0]}" "fonts/${FONTSTACKS[1]}" "fonts/${FONTSTACKS[2]}" )

    mkdir -p "$DATA_DIR/fonts" "$DATA_DIR/sprites"
    for f in "${FONTSTACKS[@]}"; do
        cp -r "$WORK_DIR/assets/fonts/$f" "$DATA_DIR/fonts/"
    done
    # Both DPI variants: MapQuickItem passes devicePixelRatio into Settings.
    cp "$WORK_DIR/assets"/sprites/v4/{light,dark}{,@2x}.{json,png} "$DATA_DIR/sprites/"
fi

# -- 3. Styles ----------------------------------------------------------------
# generate_style emits a style pointing at Protomaps' hosted tiles; we rewrite
# the three resource keys to local absolute paths.
#
# The pmtiles://file:// nesting is mandatory: PMTilesFileSource strips only the
# pmtiles:// prefix and re-requests the remainder, so a bare pmtiles:///path
# yields inner URL "/path", which no file source accepts.
if ! have "$DATA_DIR/style-dark.json"; then
    log "Generating styles"
    # usage: generate_style OUTPUT TILEJSON_URL FLAVOR LANG [SPRITE_URL] [GLYPHS_URL]
    # -p tsx: the package's bin is a .ts entrypoint and does not vendor its runner.
    for flavor in light dark; do
        npx -y -p tsx -p @protomaps/basemaps@5 generate_style \
            "$DATA_DIR/style-$flavor.json" \
            "pmtiles://file://$DATA_DIR/region.pmtiles" \
            "$flavor" en \
            "file://$DATA_DIR/sprites/$flavor" \
            "file://$DATA_DIR/fonts/{fontstack}/{range}.pbf"
        python3 -c "
import json,sys;s=json.load(open(sys.argv[1]))
print('  %s: %d layers, sources %s' % (sys.argv[1].split('/')[-1], len(s['layers']), list(s['sources'])))" \
            "$DATA_DIR/style-$flavor.json"
    done
fi

# -- 4. Routing: OSRM, MLD pipeline -------------------------------------------
# MLD rather than CH: far less RAM and much faster to build, same query API.
if ! have "$OSRM_DIR/$REGION.osrm.mldgr"; then
    log "Downloading OSM extract"
    fetch "$PBF_URL" "$OSRM_DIR/$REGION.osm.pbf"
    log "Building OSRM routing graph (this is the slow one)"
    OSRM_IMG=ghcr.io/project-osrm/osrm-backend
    docker run --rm -v "$OSRM_DIR:/data" "$OSRM_IMG" \
        osrm-extract -p /opt/car.lua "/data/$REGION.osm.pbf"
    docker run --rm -v "$OSRM_DIR:/data" "$OSRM_IMG" \
        osrm-partition "/data/$REGION.osrm"
    docker run --rm -v "$OSRM_DIR:/data" "$OSRM_IMG" \
        osrm-customize "/data/$REGION.osrm"
fi

# -- 5. Geocoding: Photon with a prebuilt index -------------------------------
if ! have "$PHOTON_DIR/photon_data"; then
    log "Downloading Photon index ($PHOTON_CC)"
    BASE="https://download1.graphhopper.com/public/extracts/by-country-code/$PHOTON_CC"
    URL="$BASE/photon-db-$PHOTON_CC-latest.tar.bz2"
    curl -fsI --max-time 20 "$URL" >/dev/null 2>&1 || \
        URL="$BASE/$(curl -fsS "$BASE/" | grep -oE "photon-db-$PHOTON_CC-[0-9]+\.tar\.bz2" | sort -u | tail -1)"
    # Download to disk first so a reset mid-transfer can resume instead of restarting
    fetch "$URL" "$WORK_DIR/photon-db.tar.bz2"
    tar -xj -C "$PHOTON_DIR" -f "$WORK_DIR/photon-db.tar.bz2"
    rm -f "$WORK_DIR/photon-db.tar.bz2"
fi
if ! have "$PHOTON_DIR/photon.jar"; then
    log "Fetching Photon $PHOTON_VER"
    # rm first: fetch() resumes with -C -, which would append onto a jar left
    # over from a different Photon version instead of replacing it.
    rm -f "$PHOTON_DIR/photon.jar"
    fetch "https://github.com/komoot/photon/releases/download/$PHOTON_VER/photon-$PHOTON_VER.jar" \
        "$PHOTON_DIR/photon.jar"
fi

# -- 6. Manifest --------------------------------------------------------------
export BBOX MAXZOOM REGION
python3 - "$DATA_DIR" "$OSRM_DIR" "$PHOTON_DIR" <<'PY'
import json, os, subprocess, sys, datetime
data, osrm, photon = sys.argv[1:4]
def du(p):
    try: return subprocess.check_output(["du","-sh",p],text=True).split()[0]
    except Exception: return "?"
pm = os.path.join(data, ".pmtiles-build")
json.dump({
    "built":        datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "bbox":         os.environ.get("BBOX"),
    "maxzoom":      os.environ.get("MAXZOOM"),
    "region":       os.environ.get("REGION"),
    "planet_build": open(pm).read().strip() if os.path.exists(pm) else None,
    "sizes":        {"basemap": du(data), "routing": du(osrm), "geocoder": du(photon)},
}, open(os.path.join(data, "manifest.json"), "w"), indent=2)
print(open(os.path.join(data, "manifest.json")).read())
PY

log "Done."
cat <<EOF
Data:     $DATA_DIR
Routing:  docker run --rm -p 127.0.0.1:5000:5000 -v $OSRM_DIR:/data \\
            ghcr.io/project-osrm/osrm-backend osrm-routed --algorithm mld /data/$REGION.osrm
Geocoder: java -jar $PHOTON_DIR/photon.jar -data-dir $PHOTON_DIR -listen-ip 127.0.0.1 -listen-port 2322

Install the systemd user units in tools/systemd/ to run both at login.
EOF
