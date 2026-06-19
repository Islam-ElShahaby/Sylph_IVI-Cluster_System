#include "AtmosBackend.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QDateTime>
#include <QTimeZone>
#include <QSettings>
#include <cmath>

AtmosBackend::AtmosBackend(QObject *parent)
    : QObject(parent)
    , m_weatherNam(new QNetworkAccessManager(this))
    , m_geoNam(new QNetworkAccessManager(this))
{
    connect(m_weatherNam, &QNetworkAccessManager::finished,
            this, &AtmosBackend::onWeatherReply);
    connect(m_geoNam, &QNetworkAccessManager::finished,
            this, &AtmosBackend::onGeoReply);

    m_refreshTimer.setInterval(30 * 60 * 1000);   // 30 min; onWeatherReply retunes it
    connect(&m_refreshTimer, &QTimer::timeout, this, &AtmosBackend::refresh);
    m_refreshTimer.start();

    load();
    fetchWeather(m_latitude, m_longitude);
}

void AtmosBackend::load()
{
    QSettings s;
    s.beginGroup("weather");
    m_latitude        = s.value("latitude",  m_latitude).toDouble();
    m_longitude       = s.value("longitude", m_longitude).toDouble();
    m_cityName        = s.value("city",      m_cityName).toString();
    m_temperatureUnit = s.value("tempUnit",  m_temperatureUnit).toString();
    m_windSpeedUnit   = s.value("windUnit",  m_windSpeedUnit).toString();
    s.endGroup();
}

void AtmosBackend::save()
{
    QSettings s;
    s.beginGroup("weather");
    s.setValue("latitude",  m_latitude);
    s.setValue("longitude", m_longitude);
    s.setValue("city",      m_cityName);
    s.setValue("tempUnit",  m_temperatureUnit);
    s.setValue("windUnit",  m_windSpeedUnit);
    s.endGroup();
}

void AtmosBackend::setLocation(double lat, double lon, const QString &city)
{
    m_cityName = city;
    save();
    fetchWeather(lat, lon);
}

void AtmosBackend::setTemperatureUnit(const QString &unit)
{
    if (m_temperatureUnit == unit) return;
    m_temperatureUnit = unit;
    save();
    emit unitsChanged();
    fetchWeather(m_latitude, m_longitude);
}

void AtmosBackend::setWindSpeedUnit(const QString &unit)
{
    if (m_windSpeedUnit == unit) return;
    m_windSpeedUnit = unit;
    save();
    emit unitsChanged();
    fetchWeather(m_latitude, m_longitude);
}

void AtmosBackend::fetchWeather(double latitude, double longitude)
{
    m_latitude  = latitude;
    m_longitude = longitude;
    save();

    m_loading = true;
    emit loadingChanged();

    QUrl url(QStringLiteral("https://api.open-meteo.com/v1/forecast"));
    QUrlQuery q;
    q.addQueryItem("latitude",  QString::number(latitude, 'f', 4));
    q.addQueryItem("longitude", QString::number(longitude, 'f', 4));
    q.addQueryItem("hourly",
                   "temperature_2m,relative_humidity_2m,dewpoint_2m,"
                   "apparent_temperature,precipitation_probability,"
                   "precipitation,surface_pressure,pressure_msl,"
                   "visibility,wind_speed_10m,wind_direction_10m,"
                   "uv_index,is_day,weather_code");
    q.addQueryItem("daily",
                   "sunrise,sunset,sunshine_duration,"
                   "temperature_2m_max,temperature_2m_min,"
                   "precipitation_probability_max,uv_index_max,"
                   "weather_code,precipitation_sum,"
                   "wind_speed_10m_max,wind_direction_10m_dominant");
    q.addQueryItem("past_days", "5");
    q.addQueryItem("forecast_days", "7");
    q.addQueryItem("timezone", "auto");
    // Unit selection
    q.addQueryItem("temperature_unit", m_temperatureUnit);
    q.addQueryItem("wind_speed_unit",  m_windSpeedUnit);
    url.setQuery(q);

    m_weatherNam->get(QNetworkRequest(url));
}

void AtmosBackend::searchCity(const QString &name)
{
    if (name.trimmed().isEmpty()){
        m_searchResults.clear();
        emit searchResultsChanged();
    } else {
        QUrl url(QStringLiteral("https://geocoding-api.open-meteo.com/v1/search"));
        QUrlQuery q;
        q.addQueryItem("name", name.trimmed());
        q.addQueryItem("count", "6");
        q.addQueryItem("language", "en");
        q.addQueryItem("format", "json");
        url.setQuery(q);

        m_geoNam->get(QNetworkRequest(url));
    }
}

void AtmosBackend::onWeatherReply(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        m_errorString = reply->errorString();
        m_loading = false;
        m_refreshTimer.start(60 * 1000);   // retry in 1 min
        emit errorChanged();
        emit loadingChanged();
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    if (!doc.isObject()) {
        m_errorString = QStringLiteral("Invalid JSON response");
        m_loading = false;
        m_refreshTimer.start(60 * 1000);   // retry in 1 min
        emit errorChanged();
        emit loadingChanged();
        return;
    }

    parseWeatherJson(doc.object());

    m_errorString.clear();
    m_loading = false;
    m_refreshTimer.start(30 * 60 * 1000);   // next refresh in 30 min
    emit dataChanged();
    emit errorChanged();
    emit loadingChanged();
}

void AtmosBackend::onGeoReply(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        m_searchResults.clear();
        emit searchResultsChanged();
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonArray results = doc.object().value("results").toArray();

    m_searchResults.clear();
    for (const QJsonValue &val : std::as_const(results)) {
        QJsonObject obj = val.toObject();
        QVariantMap entry;
        entry["name"]      = obj["name"].toString();
        entry["country"]   = obj["country"].toString();
        entry["admin1"]    = obj["admin1"].toString();
        entry["latitude"]  = obj["latitude"].toDouble();
        entry["longitude"] = obj["longitude"].toDouble();
        m_searchResults.append(entry);
    }
    emit searchResultsChanged();
}

void AtmosBackend::parseWeatherJson(const QJsonObject &root)
{
    const QJsonObject hourlyObj = root["hourly"].toObject();
    const QJsonArray times       = hourlyObj["time"].toArray();
    const QJsonArray temps       = hourlyObj["temperature_2m"].toArray();
    const QJsonArray humids      = hourlyObj["relative_humidity_2m"].toArray();
    const QJsonArray dewpoints   = hourlyObj["dewpoint_2m"].toArray();
    const QJsonArray appTemps    = hourlyObj["apparent_temperature"].toArray();
    const QJsonArray precipProbs = hourlyObj["precipitation_probability"].toArray();
    const QJsonArray precips     = hourlyObj["precipitation"].toArray();
    const QJsonArray surfPress   = hourlyObj["surface_pressure"].toArray();
    const QJsonArray seaPress    = hourlyObj["pressure_msl"].toArray();
    const QJsonArray vis         = hourlyObj["visibility"].toArray();
    const QJsonArray windSpeeds  = hourlyObj["wind_speed_10m"].toArray();
    const QJsonArray windDirs    = hourlyObj["wind_direction_10m"].toArray();
    const QJsonArray uvIndices   = hourlyObj["uv_index"].toArray();
    const QJsonArray isDayArr    = hourlyObj["is_day"].toArray();
    const QJsonArray hWeatherCode = hourlyObj["weather_code"].toArray();

    QString tz = root["timezone"].toString();
    QDateTime now = QDateTime::currentDateTime();
    if (!tz.isEmpty()) {
        QTimeZone zone(tz.toUtf8());
        if (zone.isValid())
            now = now.toTimeZone(zone);
    }
    QString nowStr = now.toString("yyyy-MM-ddTHH:00");

    int currentIdx = -1;
    for (int i = 0; i < times.size(); ++i) {
        if (times[i].toString() == nowStr) {
            currentIdx = i;
            break;
        }
    }
    if (currentIdx < 0 && !times.isEmpty()) {
        for (int i = times.size() - 1; i >= 0; --i) {
            QDateTime t = QDateTime::fromString(times[i].toString(), Qt::ISODate);
            if (t <= now) { currentIdx = i; break; }
        }
        if (currentIdx < 0) currentIdx = 0;
    }

    auto safeDouble = [](const QJsonArray &a, int idx) -> QVariant {
        if (idx < 0 || idx >= a.size() || a[idx].isNull()) return QVariant();
        return a[idx].toDouble();
    };
    auto safeInt = [](const QJsonArray &a, int idx) -> QVariant {
        if (idx < 0 || idx >= a.size() || a[idx].isNull()) return QVariant();
        return a[idx].toInt();
    };

    m_currentWeather.clear();
    m_currentWeather["temperature"]        = safeDouble(temps, currentIdx);
    m_currentWeather["humidity"]            = safeInt(humids, currentIdx);
    m_currentWeather["dewpoint"]            = safeDouble(dewpoints, currentIdx);
    m_currentWeather["apparentTemperature"] = safeDouble(appTemps, currentIdx);
    m_currentWeather["precipProbability"]   = safeInt(precipProbs, currentIdx);
    m_currentWeather["precipitation"]       = safeDouble(precips, currentIdx);
    m_currentWeather["surfacePressure"]     = safeDouble(surfPress, currentIdx);
    m_currentWeather["seaLevelPressure"]    = safeDouble(seaPress, currentIdx);
    m_currentWeather["visibility"]          = safeDouble(vis, currentIdx);
    m_currentWeather["windSpeed"]           = safeDouble(windSpeeds, currentIdx);
    m_currentWeather["windDirection"]       = safeDouble(windDirs, currentIdx);
    m_currentWeather["windDirectionStr"]    = windDirectionString(currentIdx >= 0 && currentIdx < windDirs.size() ? windDirs[currentIdx].toDouble() : 0);
    m_currentWeather["uvIndex"]             = safeDouble(uvIndices, currentIdx);
    m_currentWeather["isDay"]               = (currentIdx >= 0 && currentIdx < isDayArr.size()) ? (isDayArr[currentIdx].toInt() == 1) : true;
    m_currentWeather["time"]                = (currentIdx >= 0 && currentIdx < times.size()) ? times[currentIdx].toString() : QString();

    m_hourlyModel.clear();
    int hourlyEnd = qMin(currentIdx + 48, (int)times.size());
    for (int i = currentIdx; i < hourlyEnd; ++i) {
        QVariantMap h;
        h["time"]              = times[i].toString();
        h["temperature"]       = safeDouble(temps, i);
        h["humidity"]          = safeInt(humids, i);
        h["precipProbability"] = safeInt(precipProbs, i);
        h["windSpeed"]         = safeDouble(windSpeeds, i);
        h["uvIndex"]           = safeDouble(uvIndices, i);
        h["isDay"]             = isDayArr[i].toInt() == 1;
        h["weatherCode"]       = safeInt(hWeatherCode, i);
        m_hourlyModel.append(h);
    }

    const QJsonObject dailyObj     = root["daily"].toObject();
    const QJsonArray dDates        = dailyObj["time"].toArray();
    const QJsonArray dTMax         = dailyObj["temperature_2m_max"].toArray();
    const QJsonArray dTMin         = dailyObj["temperature_2m_min"].toArray();
    const QJsonArray dSunrise      = dailyObj["sunrise"].toArray();
    const QJsonArray dSunset       = dailyObj["sunset"].toArray();
    const QJsonArray dSunshine     = dailyObj["sunshine_duration"].toArray();
    const QJsonArray dPrecipMax    = dailyObj["precipitation_probability_max"].toArray();
    const QJsonArray dUvMax        = dailyObj["uv_index_max"].toArray();
    const QJsonArray dWeatherCode  = dailyObj["weather_code"].toArray();
    const QJsonArray dPrecipSum    = dailyObj["precipitation_sum"].toArray();
    const QJsonArray dWindMax      = dailyObj["wind_speed_10m_max"].toArray();
    const QJsonArray dWindDir      = dailyObj["wind_direction_10m_dominant"].toArray();

    m_dailyModel.clear();
    for (int i = 0; i < dDates.size(); ++i) {
        QVariantMap d;
        d["date"]              = dDates[i].toString();
        d["tempMax"]           = safeDouble(dTMax, i);
        d["tempMin"]           = safeDouble(dTMin, i);
        d["sunrise"]           = dSunrise.size() > i ? dSunrise[i].toString() : QString();
        d["sunset"]            = dSunset.size()  > i ? dSunset[i].toString()  : QString();
        d["sunshineDuration"]  = safeDouble(dSunshine, i);
        d["precipProbability"] = safeInt(dPrecipMax, i);
        d["precipSum"]         = safeDouble(dPrecipSum, i);
        d["uvIndexMax"]        = safeDouble(dUvMax, i);
        d["weatherCode"]       = safeInt(dWeatherCode, i);
        d["windSpeedMax"]      = safeDouble(dWindMax, i);
        d["windDirection"]     = safeDouble(dWindDir, i);
        d["windDirectionStr"]  = windDirectionString(dWindDir.size() > i ? dWindDir[i].toDouble() : 0);
        m_dailyModel.append(d);
    }
    QString todayStr = now.date().toString("yyyy-MM-dd");
    for (int i = 0; i < dDates.size(); ++i) {
        if (dDates[i].toString() == todayStr) {
            m_currentWeather["sunrise"]          = dSunrise[i].toString();
            m_currentWeather["sunset"]           = dSunset[i].toString();
            m_currentWeather["sunshineDuration"] = safeDouble(dSunshine, i);
            m_currentWeather["weatherCode"]      = safeInt(dWeatherCode, i);
            m_currentWeather["tempMax"]          = safeDouble(dTMax, i);
            m_currentWeather["tempMin"]          = safeDouble(dTMin, i);
            break;
        }
    }
}

QString AtmosBackend::windDirectionString(double degrees) const
{
    if (std::isnan(degrees)) return QStringLiteral("—");
    const QStringList dirs = {
        "N","NNE","NE","ENE","E","ESE","SE","SSE",
        "S","SSW","SW","WSW","W","WNW","NW","NNW"
    };
    int idx = static_cast<int>(std::round(degrees / 22.5)) % 16;
    return dirs[idx];
}
