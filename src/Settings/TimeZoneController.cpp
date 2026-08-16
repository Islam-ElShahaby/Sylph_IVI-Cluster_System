#include "TimeZoneController.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QTimeZone>

#include <time.h>

namespace {

const char *kZoneInfoDir = "/usr/share/zoneinfo/";
const char *kLocaltime   = "/etc/localtime";
const char *kTimezone    = "/etc/timezone";
const char *kOtherRegion = "Other";

QString readEtcTimezone()
{
    QFile f(QString::fromLatin1(kTimezone));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromUtf8(f.readAll()).trimmed();
}

} // namespace

TimeZoneController::TimeZoneController(QObject *parent) : QObject(parent)
{
    // /etc/timezone is the name the user picked; QTimeZone::systemTimeZone() only
    // reports what glibc resolved, which is "UTC" whenever /etc/localtime is absent.
    // Prefer the explicit file and fall back to Qt.
    m_zoneId = readEtcTimezone();
    if (m_zoneId.isEmpty())
        m_zoneId = QString::fromUtf8(QTimeZone::systemTimeZoneId());
}

QString TimeZoneController::zoneId() const
{
    return m_zoneId;
}

QStringList TimeZoneController::regions() const
{
    QStringList out;
    const QList<QByteArray> ids = QTimeZone::availableTimeZoneIds();
    for (const QByteArray &raw : ids) {
        const QString region = regionOf(QString::fromUtf8(raw));
        if (!out.contains(region))
            out.append(region);
    }
    out.sort();
    return out;
}

QStringList TimeZoneController::citiesIn(const QString &region) const
{
    QStringList out;
    const QList<QByteArray> ids = QTimeZone::availableTimeZoneIds();
    for (const QByteArray &raw : ids) {
        const QString id = QString::fromUtf8(raw);
        if (regionOf(id) == region)
            out.append(cityOf(id));
    }
    out.sort();
    return out;
}

int TimeZoneController::offsetMinutes(const QString &id) const
{
    const QTimeZone tz(id.toUtf8());
    if (!tz.isValid())
        return 0;
    return tz.offsetFromUtc(QDateTime::currentDateTimeUtc()) / 60;
}

QString TimeZoneController::offsetLabel(const QString &id) const
{
    const int min = offsetMinutes(id);
    const int abs = min < 0 ? -min : min;
    return QStringLiteral("GMT%1%2:%3")
        .arg(min < 0 ? QLatin1Char('-') : QLatin1Char('+'))
        .arg(abs / 60, 2, 10, QLatin1Char('0'))
        .arg(abs % 60, 2, 10, QLatin1Char('0'));
}

QString TimeZoneController::regionOf(const QString &id) const
{
    const int slash = id.indexOf(QLatin1Char('/'));
    return slash < 0 ? QString::fromLatin1(kOtherRegion) : id.left(slash);
}

QString TimeZoneController::cityOf(const QString &id) const
{
    const int slash = id.indexOf(QLatin1Char('/'));
    // Keep the tail whole: "America/Argentina/Salta" -> "Argentina/Salta", so the
    // city list stays unambiguous for the three-level zones.
    return slash < 0 ? id : id.mid(slash + 1);
}

bool TimeZoneController::setZone(const QString &id)
{
    const QString zoneFile = QString::fromLatin1(kZoneInfoDir) + id;
    if (!QFile::exists(zoneFile)) {
        qWarning() << "[TimeZone] no such zone file:" << zoneFile;
        return false;
    }

    // /etc/localtime is a symlink and QFile::link will not overwrite, so drop it
    // first. remove() failing is only fatal if the file is still there afterwards
    // (it legitimately does not exist on an image built without tzdata).
    QFile::remove(QString::fromLatin1(kLocaltime));
    if (QFile::exists(QString::fromLatin1(kLocaltime))
        || !QFile::link(zoneFile, QString::fromLatin1(kLocaltime))) {
        qWarning() << "[TimeZone] could not repoint" << kLocaltime
                   << "at" << zoneFile << "- is /etc writable?";
        return false;
    }

    QFile tzName(QString::fromLatin1(kTimezone));
    if (tzName.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        tzName.write(id.toUtf8() + '\n');

    // Apply to the running process too. The symlink alone only takes effect for
    // programs that start afterwards, because glibc caches the zone after its
    // first localtime() call - TZ + tzset() is what makes it immediate here.
    qputenv("TZ", id.toUtf8());
    tzset();

    m_zoneId = id;
    emit zoneChanged();
    return true;
}
