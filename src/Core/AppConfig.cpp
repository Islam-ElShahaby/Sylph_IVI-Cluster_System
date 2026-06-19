#include "AppConfig.h"
#include <QCoreApplication>
#include <QProcessEnvironment>
#include <QDebug>

AppConfig::AppConfig(QObject *parent) : QObject(parent)
{
    // Read the key securely from the OS environment
    m_mapApiKey = qEnvironmentVariable("SYLPH_MAP_API_KEY");
    m_googleApiKey = qEnvironmentVariable("SYLPH_GOOGLE_API_KEY");

    if (m_mapApiKey.isEmpty()) {
        qWarning() << "[Security] SYLPH_MAP_API_KEY environment variable is not set! Maps will fail to load.";
    }

    if (m_googleApiKey.isEmpty()) {
        qWarning() << "[Security] SYLPH_GOOGLE_API_KEY environment variable is not set! Maps will fail to load.";
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