#ifndef ATMOSBACKEND_H
#define ATMOSBACKEND_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>

// Weather backend (Open-Meteo). Adapted from the Atmos app and exposed to QML
// as a singleton (WeatherController) so the weather screen and the weather
// settings pane share one source of truth (location, units, data).
class AtmosBackend : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantMap  currentWeather READ currentWeather NOTIFY dataChanged)
    Q_PROPERTY(QVariantList hourlyModel    READ hourlyModel    NOTIFY dataChanged)
    Q_PROPERTY(QVariantList dailyModel     READ dailyModel     NOTIFY dataChanged)
    Q_PROPERTY(QVariantList searchResults  READ searchResults  NOTIFY searchResultsChanged)
    Q_PROPERTY(bool         loading        READ loading        NOTIFY loadingChanged)
    Q_PROPERTY(QString      errorString    READ errorString    NOTIFY errorChanged)
    Q_PROPERTY(QString      cityName       READ cityName       NOTIFY dataChanged)
    Q_PROPERTY(double       latitude       READ latitude       NOTIFY dataChanged)
    Q_PROPERTY(double       longitude      READ longitude      NOTIFY dataChanged)
    // Units: "celsius"/"fahrenheit" and "kmh"/"mph"/"ms"/"kn"
    Q_PROPERTY(QString temperatureUnit READ temperatureUnit WRITE setTemperatureUnit NOTIFY unitsChanged)
    Q_PROPERTY(QString windSpeedUnit   READ windSpeedUnit   WRITE setWindSpeedUnit   NOTIFY unitsChanged)

public:
    explicit AtmosBackend(QObject *parent = nullptr);

    QVariantMap  currentWeather() const { return m_currentWeather; }
    QVariantList hourlyModel()    const { return m_hourlyModel; }
    QVariantList dailyModel()     const { return m_dailyModel; }
    QVariantList searchResults()  const { return m_searchResults; }
    bool         loading()        const { return m_loading; }
    QString      errorString()    const { return m_errorString; }
    QString      cityName()       const { return m_cityName; }
    double       latitude()       const { return m_latitude; }
    double       longitude()      const { return m_longitude; }
    QString      temperatureUnit() const { return m_temperatureUnit; }
    QString      windSpeedUnit()   const { return m_windSpeedUnit; }

    Q_INVOKABLE void fetchWeather(double lat, double lon);
    Q_INVOKABLE void searchCity(const QString &name);
    Q_INVOKABLE void clearSearchResults() {
        m_searchResults.clear();
        emit searchResultsChanged();
    }
    // Set the active location (and remember it) then refresh.
    Q_INVOKABLE void setLocation(double lat, double lon, const QString &city);
    Q_INVOKABLE void refresh() { fetchWeather(m_latitude, m_longitude); }

    void setTemperatureUnit(const QString &unit);
    void setWindSpeedUnit(const QString &unit);

signals:
    void dataChanged();
    void loadingChanged();
    void errorChanged();
    void searchResultsChanged();
    void unitsChanged();

private slots:
    void onWeatherReply(QNetworkReply *reply);
    void onGeoReply(QNetworkReply *reply);

private:
    void parseWeatherJson(const QJsonObject &root);
    QString windDirectionString(double degrees) const;
    void load();   // restore persisted location + units
    void save();   // persist location + units

    QNetworkAccessManager *m_weatherNam;
    QNetworkAccessManager *m_geoNam;
    QTimer m_refreshTimer;   // 30 min normally, 1 min after a failed fetch

    QVariantMap  m_currentWeather;
    QVariantList m_hourlyModel;
    QVariantList m_dailyModel;
    QVariantList m_searchResults;

    bool    m_loading = false;
    QString m_errorString;
    QString m_cityName  = QStringLiteral("Cairo");
    double  m_latitude  = 30.0444;
    double  m_longitude = 31.2357;
    QString m_temperatureUnit = QStringLiteral("celsius");
    QString m_windSpeedUnit   = QStringLiteral("kmh");
};

#endif // ATMOSBACKEND_H
