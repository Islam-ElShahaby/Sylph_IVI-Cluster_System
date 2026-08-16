#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

// Reads and sets the SYSTEM time zone (/etc/localtime), unlike the rest of the
// Date & Time pane which is display-only. Needs write access to /etc; Sylph runs
// as root on the qvm guest (see sylph-eglfs.init), and setZone() reports failure
// rather than throwing if it does not.
//
// The zone list comes from Qt, which reads the tzdata installed in the image
// (IMAGE_INSTALL "tzdata" in qnxvimg-sylph-image.bb). With no tzdata present Qt
// offers UTC only, so the picker degrades to one entry instead of misbehaving.
class TimeZoneController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString zoneId READ zoneId NOTIFY zoneChanged)

public:
    explicit TimeZoneController(QObject *parent = nullptr);

    QString zoneId() const;

    // "Africa", "America", ... - the first path element of every available zone,
    // deduplicated and sorted. Zones with no "/" (UTC, GMT) land under "Other".
    Q_INVOKABLE QStringList regions() const;

    // City half of every zone in `region`, sorted. "Africa" -> ["Cairo", "Lagos"...]
    Q_INVOKABLE QStringList citiesIn(const QString &region) const;

    // Current UTC offset of `id` in minutes, DST included. Recomputed on demand so
    // a DST transition is picked up without restarting the app.
    Q_INVOKABLE int offsetMinutes(const QString &id) const;

    // "Africa/Cairo" -> "GMT+02:00"
    Q_INVOKABLE QString offsetLabel(const QString &id) const;

    Q_INVOKABLE QString regionOf(const QString &id) const;
    Q_INVOKABLE QString cityOf(const QString &id) const;

    // Repoints /etc/localtime, writes /etc/timezone, and applies the zone to this
    // process. Returns false if the zone is unknown or /etc is not writable.
    Q_INVOKABLE bool setZone(const QString &id);

signals:
    void zoneChanged();

private:
    QString m_zoneId;
};
