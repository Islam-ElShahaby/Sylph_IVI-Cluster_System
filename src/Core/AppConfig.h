#ifndef APPCONFIG_H
#define APPCONFIG_H

#include <QObject>
#include <QString>

class AppConfig : public QObject
{
    Q_OBJECT
    // Online providers (preferred when reachable)
    Q_PROPERTY(QString mapApiKey READ mapApiKey CONSTANT)
    Q_PROPERTY(QString googleApiKey READ googleApiKey CONSTANT)
    Q_PROPERTY(QString osrmFallbackUrl READ osrmFallbackUrl CONSTANT)
    // Offline map data + local service endpoints (fallback), overridable from the environment
    Q_PROPERTY(QString mapDir READ mapDir CONSTANT)
    Q_PROPERTY(QString osrmUrl READ osrmUrl CONSTANT)
    Q_PROPERTY(QString geocoderUrl READ geocoderUrl CONSTANT)
public:
    explicit AppConfig(QObject *parent = nullptr);

    QString mapApiKey() const;
    QString googleApiKey() const;
    QString osrmFallbackUrl() const;
    QString mapDir() const;
    QString osrmUrl() const;
    QString geocoderUrl() const;

private:
    QString m_mapApiKey;
    QString m_googleApiKey;
    QString m_osrmFallbackUrl;
    QString m_mapDir;
    QString m_osrmUrl;
    QString m_geocoderUrl;
};

#endif // APPCONFIG_H
