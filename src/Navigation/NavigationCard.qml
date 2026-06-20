import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Sylph.Core 1.0
import MapLibre 3.0

Item {
    id: root

    // FIX 1: Create a stable QtObject reference to maintain reactive bindings
    property QtObject appRoot: typeof mainRoot !== "undefined" ? mainRoot : null

    // Import color variables dynamically tied to the appRoot
    property color colorSurface: appRoot ? appRoot.colorSurface : "#c80e0a17"
    property color colorSurfaceAlt: appRoot ? appRoot.colorSurfaceAlt : "#dd141021"
    property color colorStroke: appRoot ? appRoot.colorStroke : "#2bffffff"
    property color colorTextPrimary: appRoot ? appRoot.colorTextPrimary : "#ffffff"
    property color colorTextMuted: appRoot ? appRoot.colorTextMuted : "#eae6f8"
    property color colorTextSubtle: appRoot ? appRoot.colorTextSubtle : "#b8b2c8"
    property color colorAccent: appRoot ? appRoot.colorAccent : "#c0b3ff"
    property color colorAccentAlt: appRoot ? appRoot.colorAccentAlt : "#7de2ff"

    property int radiusLarge: appRoot ? appRoot.radiusLarge : 28
    property int radiusSmall: appRoot ? appRoot.radiusSmall : 16

    property bool isNightMode: appRoot ? appRoot.isNightMode : true

    // Highly distinct contrast colors for map overlays over bright/dark styles
    property color colorMapOverlay: isNightMode ? Qt.rgba(0.08, 0.07, 0.13, 0.88) : "#ffffff"
    property color colorMapOverlayStroke: isNightMode ? Qt.rgba(1, 1, 1, 0.15) : "#c5c3d1"
    property color colorMapTextPrimary: isNightMode ? "#ffffff" : "#110f1a"
    property color colorMapTextMuted: isNightMode ? "#eae6f8" : "#322f42"
    property color colorMapTextSubtle: isNightMode ? "#b8b2c8" : "#4a475d"

    property bool mapReloadToggle: true

    // Navigation state variables
    property double zoomLevel: 1.5
    property bool isVoiceMuted: false
    property bool is3DMode: true
    property bool isNorthUp: false
    property string currentStreet: "System Ready"
    property string nextTurnStreet: "Select Destination"
    property string nextTurnDistance: ""
    property string nextTurnIcon: "^"
    property string etaTime: ""
    property int timeRemaining: 0
    property real distanceRemaining: 0.0
    property real totalRouteDistance: 1.0
    property string searchPlaceholder: "Search coordinates, POIs..."

    property double userLat: 30.0383
    property double userLng: 31.2102
    property double lastLat: 0.0
    property double lastLng: 0.0
    property real vehicleHeading: 0.0

    property var routeCoordinates: []
    property real navigationProgress: routeCoordinates.length > 0 ? Math.max(0.0, Math.min(1.0, 1.0 - (distanceRemaining / totalRouteDistance))) : 0.0

    property var baseStyleObj: null
    property string activeStyleUrl: ""
    property var currentRouteGeometry: null

    property bool isDemoMode: true
    property int demoCurrentSegment: 0
    property real demoSegmentProgress: 0.0

    property bool mapShouldLoad: false
    property string searchSessionToken: ""

    Timer {
        id: searchDebounceTimer
        interval: 300
        repeat: false
        onTriggered: {
            var query = searchField.text.trim();
            if (query.length > 2) {
                root.fetchSuggestions(query);
            } else {
                searchResultsModel.clear();
                searchPlaceholder = "Search coordinates, POIs...";
            }
        }
    }

    ListModel {
        id: searchResultsModel
    }

    onWidthChanged: {
        if (width > 100 && height > 100)
            mapShouldLoad = true;
    }
    onHeightChanged: {
        if (width > 100 && height > 100)
            mapShouldLoad = true;
    }

    Timer {
        id: demoDriveTimer
        interval: 100
        repeat: true
        running: false
        onTriggered: {
            if (routeCoordinates.length < 2) {
                stop();
                return;
            }

            var currentPoint = routeCoordinates[demoCurrentSegment];
            var nextPoint = routeCoordinates[demoCurrentSegment + 1];

            var segmentDistance = distanceBetween(currentPoint[0], currentPoint[1], nextPoint[0], nextPoint[1]);
            var speedKmPerSec = 50.0 / 3600.0;
            var stepDistance = speedKmPerSec * (interval / 1000.0);

            demoSegmentProgress += stepDistance / Math.max(0.0001, segmentDistance);
            if (demoSegmentProgress >= 1.0) {
                demoCurrentSegment++;
                demoSegmentProgress = 0.0;

                if (demoCurrentSegment >= routeCoordinates.length - 1) {
                    stop();
                    currentStreet = "Arrived at Destination";
                    nextTurnStreet = "Arrived";
                    nextTurnDistance = "";
                    root.userLat = routeCoordinates[routeCoordinates.length - 1][0];
                    root.userLng = routeCoordinates[routeCoordinates.length - 1][1];
                    root.updateRemainingDistance();
                    root.updateMapCamera(500);
                    return;
                }
                nextTurnStreet = "Turn onto segment " + (demoCurrentSegment + 1);
            }

            var lat = currentPoint[0] + (nextPoint[0] - currentPoint[0]) * demoSegmentProgress;
            var lng = currentPoint[1] + (nextPoint[1] - currentPoint[1]) * demoSegmentProgress;

            root.userLat = lat;
            root.userLng = lng;

            var dy = nextPoint[0] - currentPoint[0];
            var dx = Math.cos(Math.PI / 180 * currentPoint[0]) * (nextPoint[1] - currentPoint[1]);
            var angle = Math.atan2(dx, dy) * 180 / Math.PI;
            if (angle < 0)
                angle += 360;

            root.vehicleHeading = angle;
            root.updateRemainingDistance();
            root.updateMapCamera(interval);
        }
    }

    function calculateETA(minutesOffset) {
        var d = new Date();
        d.setMinutes(d.getMinutes() + minutesOffset);
        var hours = d.getHours();
        var minutes = d.getMinutes();
        var ampm = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12;
        hours = hours ? hours : 12;
        minutes = minutes < 10 ? '0' + minutes : minutes;
        return hours + ':' + minutes + ' ' + ampm;
    }

    function distanceBetween(lat1, lon1, lat2, lon2) {
        var R = 6371;
        var dLat = (lat2 - lat1) * Math.PI / 180;
        var dLon = (lon2 - lon1) * Math.PI / 180;
        var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    function updateRemainingDistance() {
        if (routeCoordinates.length < 2) {
            distanceRemaining = 0.0;
            timeRemaining = 0;
            return;
        }

        var closestIdx = 0;
        var minDist = 999999.0;
        for (var i = 0; i < routeCoordinates.length; i++) {
            var d = distanceBetween(userLat, userLng, routeCoordinates[i][0], routeCoordinates[i][1]);
            if (d < minDist) {
                minDist = d;
                closestIdx = i;
            }
        }

        var sum = 0.0;
        sum += distanceBetween(userLat, userLng, routeCoordinates[closestIdx][0], routeCoordinates[closestIdx][1]);

        for (var j = closestIdx; j < routeCoordinates.length - 1; j++) {
            sum += distanceBetween(routeCoordinates[j][0], routeCoordinates[j][1], routeCoordinates[j + 1][0], routeCoordinates[j + 1][1]);
        }

        distanceRemaining = Math.round(sum * 10) / 10;
        timeRemaining = Math.round((distanceRemaining / 50.0) * 60);
        etaTime = calculateETA(timeRemaining);
    }

    function updateMapCamera(duration) {
        if (!mapLoader.item)
            return;

        var bearingVal = 0.0;
        if ((root.is3DMode || !root.isNorthUp) && !isNaN(root.vehicleHeading) && root.vehicleHeading >= 0) {
            bearingVal = root.vehicleHeading;
        }

        var lat = root.userLat;
        var lng = root.userLng;
        var zoomVal = root.zoomLevel + 14.5;
        var pitchVal = 0.0;

        if (root.is3DMode) {
            zoomVal = root.zoomLevel + 16.2;
            pitchVal = 65.0;

            // Shift coordinate slightly forward based on vehicle heading
            // This aligns perfectly with the marker offset of 0.18 * height
            var bearingRad = bearingVal * Math.PI / 180;
            lat += 0.0006 * Math.cos(bearingRad);
            lng += 0.0006 * Math.sin(bearingRad);
        }

        if (typeof mapLoader.item.easeTo === "function") {
            try {
                mapLoader.item.easeTo({
                    "center": [lat, lng],
                    "zoom": zoomVal,
                    "bearing": bearingVal,
                    "pitch": pitchVal
                }, {
                    "duration": duration || 0
                });
            } catch (e) {}
        }
    }

    // Translate all mapbox:// protocol URLs to public HTTPS equivalents
    // so that MapLibre (which doesn't understand the proprietary protocol) can fetch them.
    function rewriteMapboxUrls(styleObj, apiKey) {
        var suffix = "?access_token=" + apiKey;

        // Sprite: mapbox://sprites/mapbox/navigation-night-v1
        //      -> https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/sprite?access_token=...
        if (typeof styleObj.sprite === "string" && styleObj.sprite.indexOf("mapbox://sprites/") === 0) {
            var spritePath = styleObj.sprite.replace("mapbox://sprites/", "");
            styleObj.sprite = "https://api.mapbox.com/styles/v1/" + spritePath + "/sprite" + suffix;
        }

        // Glyphs: mapbox://fonts/mapbox/{fontstack}/{range}.pbf
        //      -> https://api.mapbox.com/fonts/v1/mapbox/{fontstack}/{range}.pbf?access_token=...
        if (typeof styleObj.glyphs === "string" && styleObj.glyphs.indexOf("mapbox://fonts/") === 0) {
            styleObj.glyphs = styleObj.glyphs.replace("mapbox://fonts/", "https://api.mapbox.com/fonts/v1/") + suffix;
        }

        // Sources: rewrite mapbox:// tile source URLs
        var sourceKeys = Object.keys(styleObj.sources);
        for (var i = 0; i < sourceKeys.length; i++) {
            var src = styleObj.sources[sourceKeys[i]];

            // Source with a "url" field like "mapbox://mapbox.mapbox-streets-v8"
            if (typeof src.url === "string" && src.url.indexOf("mapbox://") === 0) {
                var tilesetIds = src.url.replace("mapbox://", "");
                // Convert to TileJSON endpoint
                src.url = "https://api.mapbox.com/v4/" + tilesetIds + ".json" + suffix;
            }

            // Source with "tiles" array entries like "mapbox://tiles/..."
            if (Array.isArray(src.tiles)) {
                for (var t = 0; t < src.tiles.length; t++) {
                    if (typeof src.tiles[t] === "string" && src.tiles[t].indexOf("mapbox://") === 0) {
                        var tilePath = src.tiles[t].replace("mapbox://tiles/", "");
                        src.tiles[t] = "https://api.mapbox.com/v4/" + tilePath + suffix;
                    }
                }
            }
        }
    }

    function loadBaseStyle() {
        var apiKey = AppConfig.mapApiKey;
        var styleName = root.isNightMode ? "navigation-night-v1" : "navigation-day-v1";

        // 1. Upgrade to Mapbox's Premium Navigation Style
        var url = "https://api.mapbox.com/styles/v1/mapbox/" + styleName + "?access_token=" + apiKey;

        console.log("[Navigation] Loading Style:", url); // Debug

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        baseStyleObj = JSON.parse(xhr.responseText);
                        rewriteMapboxUrls(baseStyleObj, apiKey);
                        inject3DBuildings(baseStyleObj);

                        root.activeStyleUrl = "";
                        var hasRoute = !!currentRouteGeometry;
                        Qt.callLater(function () {
                            if (hasRoute) {
                                injectRouteLayer(currentRouteGeometry);
                            } else {
                                root.activeStyleUrl = "data:application/json;charset=utf-8," + encodeURIComponent(JSON.stringify(baseStyleObj));
                            }
                            root.mapReloadToggle = true;
                        });
                        return;
                    } catch (e) {
                        console.log("[Navigation] Style parse exception:", e);
                    }
                }
                root.activeStyleUrl = "";
                root.mapReloadToggle = true;
            }
        };
        xhr.open("GET", url, true);
        xhr.send();
    }

    function inject3DBuildings(styleObj) {
        // Hide existing 2D building layers to prevent overlap with our 3D extrusions
        for (var i = 0; i < styleObj.layers.length; i++) {
            if (styleObj.layers[i].id.indexOf("building") !== -1) {
                styleObj.layers[i].layout = styleObj.layers[i].layout || {};
                styleObj.layers[i].layout.visibility = "none";
            }
        }

        // Global directional lighting for realistic wall/roof shading
        styleObj.light = {
            "anchor": "map",
            "color": root.isNightMode ? "#c6d2e6" : "#ffffff",
            "intensity": root.isNightMode ? 0.45 : 0.6,
            "position": [1.15, 210, 30]
        };

        // Determine the best available vector source that contains a "building" layer.
        // Mapbox navigation styles already include a "composite" source with buildings data --
        // reuse it instead of injecting a duplicate tile source.
        var sourceId = "composite";
        var sourceLayer = "building";
        if (!styleObj.sources[sourceId]) {
            // Fallback: find any vector source
            var keys = Object.keys(styleObj.sources);
            for (var k = 0; k < keys.length; k++) {
                if (styleObj.sources[keys[k]].type === "vector") {
                    sourceId = keys[k];
                    break;
                }
            }
        }

        var buildingLayer = {
            "id": "3d-buildings-extrusion",
            "source": sourceId,
            "source-layer": sourceLayer,
            "type": "fill-extrusion",
            "minzoom": 13,
            "paint": {
                "fill-extrusion-color": root.isNightMode ? "#5a6b8c" : "#d0d4df",
                // OSM height data in MENA regions is often drastically underreported (3-5m for
                // 6-story buildings). Scale reported values by 3x and enforce a 15m floor.
                // Buildings with no data at all default to 22m (typical 7-story block).
                "fill-extrusion-height": ["max", ["*", ["coalesce", ["get", "height"], ["get", "render_height"], 22.0], 3.0], 15.0],
                "fill-extrusion-base": ["coalesce", ["get", "min_height"], ["get", "render_min_height"], 0.0],
                "fill-extrusion-opacity": root.isNightMode ? 0.9 : 0.85,
                "fill-extrusion-vertical-gradient": true
            }
        };

        // Inject below text labels so street names float over the buildings,
        // but ABOVE all road lines, casings, and route lines.
        // We search backwards from the end of the layers list to find the last non-symbol
        // layer (e.g. roads, casings, route lines, water) and insert our 3D buildings right after it.
        var insertIndex = 0;
        for (var j = styleObj.layers.length - 1; j >= 0; j--) {
            if (styleObj.layers[j].type !== "symbol" && styleObj.layers[j].type !== "fill-extrusion") {
                insertIndex = j + 1;
                break;
            }
        }
        if (insertIndex === 0) {
            // Fallback: search forwards for first symbol
            for (var k = 0; k < styleObj.layers.length; k++) {
                if (styleObj.layers[k].type === "symbol") {
                    insertIndex = k;
                    break;
                }
            }
        }
        styleObj.layers.splice(insertIndex, 0, buildingLayer);
    }

    function injectRouteLayer(geometry) {
        currentRouteGeometry = geometry;
        if (!baseStyleObj)
            return;

        var styleCopy = JSON.parse(JSON.stringify(baseStyleObj));
        styleCopy.sources["route-source"] = {
            "type": "geojson",
            "data": {
                "type": "Feature",
                "properties": {},
                "geometry": geometry
            }
        };

        // Helper to format Qt QML color objects into MapLibre-safe CSS rgba() strings
        function toMapboxColor(qtColor) {
            return "rgba(" + Math.round(qtColor.r * 255) + "," + Math.round(qtColor.g * 255) + "," + Math.round(qtColor.b * 255) + "," + qtColor.a + ")";
        }

        var routeGlow = {
            "id": "route-line-glow",
            "type": "line",
            "source": "route-source",
            "layout": {
                "line-join": "round",
                "line-cap": "round"
            },
            "paint": {
                "line-color": toMapboxColor(root.colorAccent),
                "line-width": 14.0,
                "line-opacity": 0.35,
                "line-blur": 6.0
            }
        };

        var routeLayer = {
            "id": "route-line",
            "type": "line",
            "source": "route-source",
            "layout": {
                "line-join": "round",
                "line-cap": "round"
            },
            "paint": {
                "line-color": toMapboxColor(root.colorAccentAlt),
                "line-width": 6.0,
                "line-opacity": 0.95
            }
        };

        var insertIndex = styleCopy.layers.length;
        for (var i = 0; i < styleCopy.layers.length; i++) {
            if (styleCopy.layers[i].id === "3d-buildings-extrusion") {
                insertIndex = i;
                break;
            } else if (styleCopy.layers[i].type === "symbol" && styleCopy.layers[i].id.indexOf("label") !== -1) {
                insertIndex = i;
                break;
            }
        }

        styleCopy.layers.splice(insertIndex, 0, routeGlow, routeLayer);

        var newStyleUrl = "data:application/json;charset=utf-8," + encodeURIComponent(JSON.stringify(styleCopy));

        // FIX 3: Actually force the MapLibre Loader to recreate the map instance
        if (root.activeStyleUrl !== newStyleUrl) {
            root.activeStyleUrl = newStyleUrl;
            root.mapReloadToggle = false;
            Qt.callLater(function () {
                root.mapReloadToggle = true;
            });
        }
    }

    function fetchRoute(startLat, startLng, endLat, endLng, label) {
        var xhr = new XMLHttpRequest();
        var url = "https://router.project-osrm.org/route/v1/driving/" + startLng + "," + startLat + ";" + endLng + "," + endLat + "?overview=full&geometries=geojson";

        searchPlaceholder = "Calculating route...";
        demoDriveTimer.stop();

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        if (response.routes && response.routes.length > 0) {
                            var route = response.routes[0];
                            var geojsonCoords = route.geometry.coordinates;
                            var path = [];

                            for (var i = 0; i < geojsonCoords.length; i++) {
                                path.push([geojsonCoords[i][1], geojsonCoords[i][0]]);
                            }

                            routeCoordinates = path;
                            var durationMins = Math.round(route.duration / 60);
                            var distanceKm = Math.round((route.distance / 1000) * 10) / 10;

                            totalRouteDistance = distanceKm;
                            distanceRemaining = distanceKm;
                            timeRemaining = durationMins;
                            etaTime = calculateETA(durationMins);

                            var cleanLabel = label.split(',')[0];
                            nextTurnStreet = cleanLabel;
                            currentStreet = "Navigating to " + cleanLabel;

                            if (mapLoader.item) {
                                mapLoader.item.flyTo({
                                    "center": [path[0][0], path[0][1]],
                                    "zoom": root.zoomLevel + 13.5,
                                    "bearing": 0.0,
                                    "pitch": root.is3DMode ? 60.0 : 0.0
                                }, {
                                    "duration": 2500
                                });
                            }

                            injectRouteLayer(route.geometry);
                            searchPlaceholder = "Search coordinates, POIs...";

                            if (root.isDemoMode) {
                                demoCurrentSegment = 0;
                                demoSegmentProgress = 0.0;
                                demoDriveTimer.restart();
                            }
                        } else {
                            searchPlaceholder = "No route found!";
                        }
                    } catch (e) {
                        searchPlaceholder = "Routing JSON error";
                    }
                } else {
                    searchPlaceholder = "Routing service offline";
                }
            }
        };
        xhr.open("GET", url, true);
        xhr.send();
    }

    function generateSessionToken() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
            var r = Math.random() * 16 | 0;
            var v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    function fetchSuggestions(query) {
        var googleKey = AppConfig.googleApiKey;
        if (!googleKey) {
            searchPlaceholder = "Google API Key Missing";
            return;
        }

        searchPlaceholder = "Searching...";

        // Added `origin` parameter to force Google to calculate distance_meters
        var url = "https://maps.googleapis.com/maps/api/place/autocomplete/json" + "?input=" + encodeURIComponent(query) + "&location=" + root.userLat + "," + root.userLng + "&origin=" + root.userLat + "," + root.userLng + "&radius=50000" + "&key=" + googleKey;

        console.log("[Navigation] Google Search URL:", url);
        var xhr = new XMLHttpRequest();

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        searchResultsModel.clear();

                        if (response.status === "OK" && response.predictions) {
                            var predictions = response.predictions;
                            for (var i = 0; i < predictions.length; i++) {
                                var pred = predictions[i];

                                // Format Google's returned distance
                                var distText = "";
                                if (pred.distance_meters !== undefined) {
                                    var dKm = pred.distance_meters / 1000.0;
                                    distText = (dKm < 1.0) ? Math.round(pred.distance_meters) + " m" : dKm.toFixed(1) + " km";
                                }

                                searchResultsModel.append({
                                    "placeName": pred.structured_formatting.main_text,
                                    "placeContext": pred.structured_formatting.secondary_text || "",
                                    "placeDistance": distText,
                                    "mapboxId": pred.place_id
                                });
                            }
                            searchPlaceholder = "Select a destination";
                        } else if (response.status === "ZERO_RESULTS") {
                            searchPlaceholder = "No results found";
                        } else {
                            console.log("[Navigation] Google API Error:", response.status);
                            searchPlaceholder = "API Error: " + response.status;
                        }
                    } catch (e) {
                        console.log("[Navigation] Search parse error:", e);
                        searchPlaceholder = "Search error";
                    }
                } else {
                    console.log("[Navigation] Search failed:", xhr.status, xhr.responseText);
                    searchPlaceholder = "Search failed (HTTP " + xhr.status + ")";
                }
            }
        };
        xhr.open("GET", url, true);
        xhr.send();
    }

    function retrieveLocationAndRoute(placeId, placeName) {
        var googleKey = AppConfig.googleApiKey;
        if (!googleKey)
            return;

        searchPlaceholder = "Calculating route...";

        // We only request the "geometry" field to save bandwidth and API costs
        var url = "https://maps.googleapis.com/maps/api/place/details/json" + "?place_id=" + placeId + "&fields=geometry" + "&key=" + googleKey;

        console.log("[Navigation] Google Retrieve URL:", url);
        var xhr = new XMLHttpRequest();

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);

                        if (response.status === "OK" && response.result.geometry) {
                            var loc = response.result.geometry.location;

                            // Hand off the Google coordinates to your existing routing logic!
                            // Google returns {lat: ..., lng: ...}
                            root.fetchRoute(root.userLat, root.userLng, loc.lat, loc.lng, placeName);

                            searchResultsModel.clear();
                            searchField.focus = false;
                            searchField.text = "";
                        } else {
                            searchPlaceholder = "Location details not found";
                        }
                    } catch (e) {
                        console.log("[Navigation] Retrieve parse error:", e);
                        searchPlaceholder = "Routing error";
                    }
                } else {
                    console.log("[Navigation] Retrieve failed:", xhr.status, xhr.responseText);
                    searchPlaceholder = "Retrieve failed (HTTP " + xhr.status + ")";
                }
            }
        };
        xhr.open("GET", url, true);
        xhr.send();
    }

    Component.onCompleted: loadBaseStyle()
    onIsNightModeChanged: {
        loadBaseStyle();
    }

    Connections {
        target: BtGpsController
        function onPositionChanged() {
            root.isDemoMode = false;
            demoDriveTimer.stop();

            var newLat = BtGpsController.latitude;
            var newLng = BtGpsController.longitude;

            if (BtGpsController.heading >= 0) {
                root.vehicleHeading = BtGpsController.heading;
            }

            root.lastLat = root.userLat;
            root.lastLng = root.userLng;
            root.userLat = newLat;
            root.userLng = newLng;

            currentStreet = "GPS Active";
            root.updateRemainingDistance();
            root.updateMapCamera(500);
        }

        function onActiveChanged() {
            if (BtGpsController.active) {
                currentStreet = "Bluetooth GPS Connected";
            } else {
                currentStreet = "Waiting for GPS...";
            }
        }
    }

    onDistanceRemainingChanged: {
        if (distanceRemaining > 0.0) {
            if (distanceRemaining <= 0.1 && distanceRemaining > 0.05) {
                nextTurnDistance = "100m";
                if (!isVoiceMuted && !AudioFocusManager.isCallInterruptionActive)
                    AudioFocusManager.startNavigationPrompt(3500);
            } else if (distanceRemaining <= 0.05 && distanceRemaining > 0.02) {
                nextTurnDistance = "50m";
                if (!isVoiceMuted && !AudioFocusManager.isCallInterruptionActive)
                    AudioFocusManager.startNavigationPrompt(3500);
            } else if (distanceRemaining <= 0.02 && distanceRemaining > 0.0) {
                nextTurnDistance = "Arriving";
                if (!isVoiceMuted && !AudioFocusManager.isCallInterruptionActive)
                    AudioFocusManager.startNavigationPrompt(3500);
            }
        }
    }

    onZoomLevelChanged: updateMapCamera(200)
    onIs3DModeChanged: updateMapCamera(300)
    onIsNorthUpChanged: updateMapCamera(300)

    Rectangle {
        id: cardContainer
        anchors.fill: parent
        radius: radiusLarge
        color: colorSurface
        border.color: colorStroke
        border.width: 1
        // We use the OpacityMask below instead of raw clip to ensure smooth anti-aliased corners
        clip: false

        Component {
            id: mapLibreComponent
            MapLibre {
                // Initial style is always driven by loadBaseStyle() which rewrites mapbox:// URLs.
                // Use a minimal empty style as a placeholder until the XHR completes.
                style: root.activeStyleUrl !== "" ? root.activeStyleUrl : "data:application/json;charset=utf-8," + encodeURIComponent(JSON.stringify({
                    "version": 8,
                    "name": "empty",
                    "sources": {},
                    "layers": []
                }))
            }
        }

        // -- 1. MASKED MAP CONTAINER FOR CURVED EDGES --
        Item {
            anchors.fill: parent

            Loader {
                id: mapLoader
                anchors.fill: parent
                active: root.mapShouldLoad && root.mapReloadToggle
                sourceComponent: mapLibreComponent
                onLoaded: root.updateMapCamera(0)
                visible: false // Hidden because the OpacityMask will render it
            }

            Rectangle {
                id: mapMask
                anchors.fill: parent
                radius: cardContainer.radius
                visible: false // Only used as a stencil
            }

            OpacityMask {
                anchors.fill: parent
                source: mapLoader
                maskSource: mapMask
            }
        }

        // -- 2. NEW HARDWARE-ACCELERATED CAR MARKER --
        Item {
            id: vehicleMarkerItem
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.is3DMode ? parent.height * 0.18 : 0

            Behavior on anchors.verticalCenterOffset {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }

            width: 64
            height: 64
            z: 2
            visible: mapLoader.status === Loader.Ready
            rotation: root.isNorthUp ? root.vehicleHeading : 0.0

            Behavior on rotation {
                RotationAnimation {
                    duration: 300
                    direction: RotationAnimation.Shortest
                }
            }

            // Pulsing Navigation Radar Aura
            Rectangle {
                anchors.centerIn: parent
                width: 64
                height: 64
                radius: 32
                color: "transparent"
                border.color: root.colorAccentAlt
                border.width: 1

                layer.enabled: true // Offloads pulse to Wayland compositor

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: vehicleMarkerItem.visible
                    NumberAnimation {
                        from: 0.5
                        to: 1.5
                        duration: 1500
                        easing.type: Easing.OutSine
                    }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: vehicleMarkerItem.visible
                    NumberAnimation {
                        from: 0.8
                        to: 0.0
                        duration: 1500
                        easing.type: Easing.OutSine
                    }
                }
            }

            // High-Performance Vector Car Shape
            Shape {
                anchors.centerIn: parent
                width: 24
                height: 44
                preferredRendererType: Shape.CurveRenderer

                // Car Body Shadow
                ShapePath {
                    strokeWidth: 0
                    fillColor: "#40000000"
                    startX: 4
                    startY: 6
                    PathLine {
                        x: 28
                        y: 6
                    }
                    PathLine {
                        x: 28
                        y: 50
                    }
                    PathLine {
                        x: 4
                        y: 50
                    }
                    PathLine {
                        x: 4
                        y: 6
                    }
                }

                // Main Car Body
                ShapePath {
                    strokeWidth: 1.5
                    strokeColor: "#ffffff"
                    fillColor: root.colorAccentAlt

                    startX: 12
                    startY: 0       // Nose
                    PathLine {
                        x: 24
                        y: 12
                    }
                    PathLine {
                        x: 24
                        y: 44
                    }
                    PathLine {
                        x: 0
                        y: 44
                    }
                    PathLine {
                        x: 0
                        y: 12
                    }
                    PathLine {
                        x: 12
                        y: 0
                    }
                }

                // Cockpit Glass
                ShapePath {
                    strokeWidth: 0
                    fillColor: "#151520"

                    startX: 12
                    startY: 14
                    PathLine {
                        x: 20
                        y: 20
                    }
                    PathLine {
                        x: 20
                        y: 30
                    }
                    PathLine {
                        x: 4
                        y: 30
                    }
                    PathLine {
                        x: 4
                        y: 20
                    }
                    PathLine {
                        x: 12
                        y: 14
                    }
                }
            }

            // Headlight Beams
            Rectangle {
                x: 17
                y: -10
                width: 14
                height: 28
                rotation: 15
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#00ffffff"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#40ffffff"
                    }
                }
            }
            Rectangle {
                x: 33
                y: -10
                width: 14
                height: 28
                rotation: -15
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#00ffffff"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#40ffffff"
                    }
                }
            }
        }

        // Ambient drop shadow for searchBar
        Rectangle {
            anchors.fill: searchBar
            anchors.margins: -4
            radius: searchBar.radius + 2
            color: "#000000"
            opacity: root.isNightMode ? 0.35 : 0.08
            z: searchBar.z - 1
        }

        Rectangle {
            id: searchBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            height: 52
            radius: radiusSmall
            color: colorMapOverlay
            border.color: colorMapOverlayStroke
            border.width: 1
            z: 3

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Text {
                    text: "FIND"
                    font.pixelSize: 18
                    color: colorMapTextSubtle
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fetchSuggestions(searchField.text)
                    }
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: root.searchPlaceholder
                    placeholderTextColor: colorMapTextSubtle
                    color: colorMapTextPrimary
                    font.pixelSize: 15
                    background: null
                    verticalAlignment: TextInput.AlignVCenter
                    onTextEdited: searchDebounceTimer.restart()
                    onAccepted: {
                        searchDebounceTimer.stop();
                        if (searchResultsModel.count > 0) {
                            var first = searchResultsModel.get(0);
                            root.retrieveLocationAndRoute(first.mapboxId, first.placeName);
                        } else {
                            focus = false;
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 24
                    color: colorMapOverlayStroke
                }

                Rectangle {
                    width: 1
                    height: 24
                    color: colorMapOverlayStroke
                }
            }
        }

        // Ambient drop shadows for cards
        Rectangle {
            anchors.fill: directiveCard
            anchors.margins: -4
            radius: directiveCard.radius + 2
            color: "#000000"
            opacity: root.isNightMode ? 0.35 : 0.08
            z: directiveCard.z - 1
            visible: directiveCard.visible
        }
        Rectangle {
            anchors.fill: actionsPanel
            anchors.margins: -4
            radius: actionsPanel.radius + 2
            color: "#000000"
            opacity: root.isNightMode ? 0.35 : 0.08
            z: actionsPanel.z - 1
            visible: actionsPanel.visible
        }
        Rectangle {
            anchors.fill: searchResultsDropdown
            anchors.margins: -4
            radius: searchResultsDropdown.radius + 2
            color: "#000000"
            opacity: root.isNightMode ? 0.35 : 0.08
            z: searchResultsDropdown.z - 1
            visible: searchResultsDropdown.visible
        }
        Rectangle {
            anchors.fill: tripCard
            anchors.margins: -4
            radius: tripCard.radius + 2
            color: "#000000"
            opacity: root.isNightMode ? 0.35 : 0.08
            z: tripCard.z - 1
            visible: tripCard.visible
        }

        DirectiveCard {
            id: directiveCard
            anchors.left: parent.left
            anchors.top: searchBar.bottom
            anchors.topMargin: 12
            anchors.leftMargin: 18
            z: 3
            visible: root.routeCoordinates.length > 0 && !searchField.activeFocus
            nextTurnIcon: root.nextTurnIcon
            nextTurnDistance: root.nextTurnDistance
            nextTurnStreet: root.nextTurnStreet
            currentStreet: root.currentStreet
            isPromptActive: AudioFocusManager.isNavigationPromptActive
            radiusSmall: root.radiusSmall
            colorSurface: root.colorMapOverlay
            colorStroke: root.colorMapOverlayStroke
            colorTextMuted: root.colorMapTextMuted
            colorTextPrimary: root.colorMapTextPrimary
            colorTextSubtle: root.colorMapTextSubtle
            colorAccent: root.colorAccent
            colorAccentAlt: root.colorAccentAlt
            onVoiceGuidanceRequested: if (!root.isVoiceMuted && !AudioFocusManager.isCallInterruptionActive)
                AudioFocusManager.startNavigationPrompt(4000)
        }

        MapActionsPanel {
            id: actionsPanel
            anchors.right: parent.right
            anchors.top: searchBar.bottom
            anchors.topMargin: 12
            anchors.rightMargin: 18
            z: 3
            visible: !searchField.activeFocus
            is3DMode: root.is3DMode
            isNorthUp: root.isNorthUp
            isVoiceMuted: root.isVoiceMuted
            radiusSmall: root.radiusSmall
            colorSurface: root.colorMapOverlay
            colorStroke: root.colorMapOverlayStroke
            colorTextPrimary: root.colorMapTextPrimary
            colorTextMuted: root.colorMapTextMuted
            colorAccent: root.colorAccent
            colorAccentAlt: root.colorAccentAlt
            onZoomInRequested: if (root.zoomLevel < 5.0)
                root.zoomLevel += 0.25
            onZoomOutRequested: if (root.zoomLevel > -5.0)
                root.zoomLevel -= 0.25
            onToggle3DRequested: {
                root.is3DMode = !root.is3DMode;
                if (root.is3DMode)
                    root.isNorthUp = false;
            }
            onToggleNorthUpRequested: {
                root.isNorthUp = !root.isNorthUp;
                if (root.isNorthUp)
                    root.is3DMode = false;
            }
            onToggleMuteRequested: root.isVoiceMuted = !root.isVoiceMuted
        }

        Rectangle {
            id: searchResultsDropdown
            anchors.top: searchBar.bottom
            anchors.topMargin: 8
            anchors.left: searchBar.left
            anchors.right: searchBar.right
            height: Math.min(searchResultsModel.count * 64, 320)
            radius: radiusSmall
            color: colorMapOverlay
            border.color: colorMapOverlayStroke
            border.width: 1
            z: 4
            clip: true
            visible: searchResultsModel.count > 0

            ListView {
                anchors.fill: parent
                model: searchResultsModel
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    width: ListView.view.width
                    height: 64
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 8
                        color: mouseArea.pressed ? (root.isNightMode ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.05)) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12
                            Text {
                                text: "LOC"
                                font.pixelSize: 18
                            }
                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Text {
                                    text: model.placeName
                                    color: colorMapTextPrimary
                                    font.pixelSize: 15
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 6
                                    Layout.fillWidth: true

                                    // Google Maps-style distance indicator
                                    Text {
                                        text: model.placeDistance
                                        color: root.colorAccentAlt
                                        font.pixelSize: 12
                                        font.bold: true
                                        visible: text !== ""
                                    }

                                    Text {
                                        text: "•"
                                        color: colorMapTextSubtle
                                        font.pixelSize: 12
                                        visible: model.placeDistance !== "" && model.placeContext !== ""
                                    }

                                    Text {
                                        text: model.placeContext
                                        color: colorMapTextSubtle
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.retrieveLocationAndRoute(model.mapboxId, model.placeName)
                        }
                    }
                    Rectangle {
                        width: parent.width - 24
                        height: 1
                        color: colorMapOverlayStroke
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: index < searchResultsModel.count - 1
                    }
                }
            }
        }

        TripProgressCard {
            id: tripCard
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 18
            z: 3
            visible: root.routeCoordinates.length > 0 && !searchField.activeFocus
            isNightMode: root.isNightMode
            nextTurnStreet: root.nextTurnStreet
            distanceRemaining: root.distanceRemaining
            timeRemaining: root.timeRemaining
            navigationProgress: root.navigationProgress
            etaTime: root.etaTime
            radiusSmall: root.radiusSmall
            colorSurface: root.colorMapOverlay
            colorStroke: root.colorMapOverlayStroke
            colorTextPrimary: root.colorMapTextPrimary
            colorTextSubtle: root.colorMapTextSubtle
            colorTextMuted: root.colorMapTextMuted
            colorAccent: root.colorAccent
            colorAccentAlt: root.colorAccentAlt
        }

        // -- 3. FIXED KEYBOARD DISMISSAL LAYER --
        // This explicitly drops focus from the search field when you tap the map while typing
        MouseArea {
            anchors.fill: parent
            enabled: virtualKeyboard.height > 0
            visible: virtualKeyboard.height > 0
            z: 9 // Ensure it sits right under the keyboard (which is z: 10)

            onClicked: {
                searchField.focus = false;
                root.forceActiveFocus();
            }
        }

        Rectangle {
            anchors.fill: virtualKeyboard
            anchors.margins: -4
            radius: virtualKeyboard.radius + 2
            color: "#000000"
            opacity: root.isNightMode ? 0.35 : 0.08
            z: virtualKeyboard.z - 1
            visible: virtualKeyboard.height > 0
        }

        GlassKeyboard {
            id: virtualKeyboard
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 18
            height: searchField.activeFocus ? 260 : 0
            z: 10
            clip: true
            Behavior on height {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            isNightMode: root.isNightMode
            targetField: searchField
            radiusSmall: root.radiusSmall
            colorSurface: root.colorMapOverlay
            colorStroke: root.colorMapOverlayStroke
            colorTextPrimary: root.colorMapTextPrimary
            colorTextMuted: root.colorMapTextMuted
            colorAccent: root.colorAccent
            onSearchTriggered: query => {
                root.fetchSuggestions(query);
                searchField.focus = false;
            }
        }
    }
}
