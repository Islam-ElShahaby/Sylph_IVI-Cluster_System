#ifndef APPCONFIG_H
#define APPCONFIG_H

#include <QObject>
#include <QString>

class AppConfig : public QObject
{
    Q_OBJECT
    // Expose the key as a read-only constant property to QML
    Q_PROPERTY(QString mapApiKey READ mapApiKey CONSTANT)
    Q_PROPERTY(QString googleApiKey READ googleApiKey CONSTANT)
public:
    explicit AppConfig(QObject *parent = nullptr);

    QString mapApiKey() const;
    QString googleApiKey() const;

private:
    QString m_mapApiKey;
    QString m_googleApiKey;
};

#endif // APPCONFIG_H