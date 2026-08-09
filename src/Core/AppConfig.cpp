#include "AppConfig.h"
#include <QDir>
#include <QStandardPaths>
#include <QDebug>

AppConfig::AppConfig(QObject *parent) : QObject(parent)
{
    // Online providers. Empty keys are not fatal any more -- the map falls back
    // to the local offline stack below.
    m_mapApiKey = qEnvironmentVariable("SYLPH_MAP_API_KEY");
    m_googleApiKey = qEnvironmentVariable("SYLPH_GOOGLE_API_KEY");
    m_osrmFallbackUrl = qEnvironmentVariable("SYLPH_OSRM_FALLBACK_URL",
        "https://router.project-osrm.org");

    // AppDataLocation, not CacheLocation: this data is provisioned by
    // tools/build-offline-data.sh, not regenerable on demand, and cache
    // directories are fair game for cleaners.
    m_mapDir = qEnvironmentVariable("SYLPH_MAP_DIR",
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/maps");
    m_osrmUrl = qEnvironmentVariable("SYLPH_OSRM_URL", "http://127.0.0.1:5000");
    m_geocoderUrl = qEnvironmentVariable("SYLPH_GEOCODER_URL", "http://127.0.0.1:2322");

    if (m_mapApiKey.isEmpty())
        qInfo() << "[Map] SYLPH_MAP_API_KEY not set -- using the offline basemap only.";
    if (m_googleApiKey.isEmpty())
        qInfo() << "[Map] SYLPH_GOOGLE_API_KEY not set -- using the offline geocoder only.";
    if (!QDir(m_mapDir).exists("style-dark.json")) {
        qWarning() << "[Map] No offline map data in" << m_mapDir
                   << "-- run tools/build-offline-data.sh. Offline fallback unavailable.";
    }
}

QString AppConfig::mapApiKey() const
{
    return m_mapApiKey;
}

QString AppConfig::googleApiKey() const
{
    return m_googleApiKey;
}

QString AppConfig::osrmFallbackUrl() const
{
    return m_osrmFallbackUrl;
}

QString AppConfig::mapDir() const
{
    return m_mapDir;
}

QString AppConfig::osrmUrl() const
{
    return m_osrmUrl;
}

QString AppConfig::geocoderUrl() const
{
    return m_geocoderUrl;
}
