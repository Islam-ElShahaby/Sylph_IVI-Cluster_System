#!/usr/bin/env bash
# Launch Sylph with the offline map config from .env, bringing the local
# routing/geocoding services up first if they aren't already listening.
#
#   ./run.sh              launch (starts services if needed)
#   ./run.sh --no-services skip the service check
#   ./run.sh --status      show what's up and exit
set -euo pipefail
cd "$(dirname "$0")"

set -a; [ -f .env ] && . ./.env; set +a

: "${SYLPH_MAP_DIR:=$HOME/.local/share/Sylph/Sylph/maps}"
: "${SYLPH_OSRM_URL:=http://127.0.0.1:5000}"
: "${SYLPH_GEOCODER_URL:=http://127.0.0.1:2322}"
export SYLPH_MAP_DIR SYLPH_OSRM_URL SYLPH_GEOCODER_URL

BUILD_DIR="${SYLPH_BUILD_DIR:-./build/Desktop_Qt_6_10_3-Debug}"
QT_LIB="${SYLPH_QT_LIB:-$HOME/Qt/6.10.3/gcc_64/lib}"
WORK="${SYLPH_OFFLINE_WORK:-$HOME/.cache/sylph-offline-build}"
OSRM_REGION="${SYLPH_OSRM_REGION:-egypt}"

up() { curl -fsS -o /dev/null --max-time 3 "$1" 2>/dev/null; }
osrm_up()   { up "$SYLPH_OSRM_URL/route/v1/driving/31.02,30.07;31.03,30.08"; }
photon_up() { up "$SYLPH_GEOCODER_URL/api?q=a&limit=1"; }

start_services() {
    if osrm_up; then
        echo "  routing   already up"
    elif [ -f "$WORK/osrm/$OSRM_REGION.osrm.mldgr" ]; then
        echo "  routing   starting..."
        docker rm -f sylph-osrm >/dev/null 2>&1 || true
        docker run -d --name sylph-osrm -p 127.0.0.1:5000:5000 -v "$WORK/osrm:/data" \
            ghcr.io/project-osrm/osrm-backend \
            osrm-routed --algorithm mld "/data/$OSRM_REGION.osrm" >/dev/null
    else
        echo "  routing   NO DATA -- run tools/build-offline-data.sh"
    fi

    if photon_up; then
        echo "  geocoder  already up"
    elif [ -d "$WORK/photon/photon_data" ]; then
        echo "  geocoder  starting... (indexes take ~40s to open)"
        nohup java -jar "$WORK/photon/photon.jar" -data-dir "$WORK/photon" \
            -listen-ip 127.0.0.1 -listen-port 2322 > "$WORK/photon/photon.log" 2>&1 &
        disown 2>/dev/null || true
    else
        echo "  geocoder  NO DATA -- run tools/build-offline-data.sh"
    fi

    # Give whatever we just started a chance to bind before the app queries it.
    for _ in $(seq 1 30); do
        osrm_up && photon_up && break
        sleep 2
    done
}

status() {
    echo "map data    $SYLPH_MAP_DIR"
    [ -f "$SYLPH_MAP_DIR/style-dark.json" ] && echo "            styles OK" || echo "            MISSING -- run tools/build-offline-data.sh"
    osrm_up   && echo "routing     up   $SYLPH_OSRM_URL"     || echo "routing     DOWN $SYLPH_OSRM_URL"
    photon_up && echo "geocoder    up   $SYLPH_GEOCODER_URL" || echo "geocoder    DOWN $SYLPH_GEOCODER_URL"
}

case "${1:-}" in
    --status) status; exit 0 ;;
    --no-services) shift ;;
    *) echo "Sylph offline services:"; start_services; echo ;;
esac

export LD_LIBRARY_PATH="$QT_LIB:${LD_LIBRARY_PATH:-}"
exec "$BUILD_DIR/appSylph" "$@"
