#include "RadioController.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMediaMetaData>
#include <QUrlQuery>
#include <algorithm>

RadioController::RadioController(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
    , m_model(new RadioStationsModel(this))
    , m_player(new QMediaPlayer(this))
    , m_audio(new QAudioOutput(this))
{
    m_audio->setVolume(m_volume / 100.0);
    m_player->setAudioOutput(m_audio);

    connect(m_player, &QMediaPlayer::playbackStateChanged, this, &RadioController::handlePlaybackState);
    connect(m_player, &QMediaPlayer::mediaStatusChanged, this, &RadioController::handleMediaStatusChanged);
    connect(m_player, &QMediaPlayer::metaDataChanged, this, &RadioController::handleMetaDataChanged);
    connect(m_player, &QMediaPlayer::errorOccurred, this, &RadioController::handleError);

    refreshFilters();
    setNowPlaying("No station");
}

void RadioController::searchStations(const QString &filter, const QString &value)
{
    QString trimmed = value.trimmed();
    if (trimmed.isEmpty()) {
        m_model->clear();
        setSelectedIndex(-1);
        setLastError("Provide a search value.");
        return;
    }

    setLastError("");
    setLoading(true);

    QNetworkRequest request(buildSearchUrl(filter, trimmed));
    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { onStationsReplyFinished(reply); });
}

void RadioController::searchStationsAdvanced(const QString &name, const QString &tag, const QString &country, const QString &language)
{
    QString cleanName = name.trimmed();
    QString cleanTag = normalizedFilterValue(tag);
    QString cleanCountry = normalizedFilterValue(country);
    QString cleanLanguage = normalizedLanguageValue(language);

    if (cleanName.isEmpty() && cleanTag.isEmpty() && cleanCountry.isEmpty() && cleanLanguage.isEmpty()) {
        setLastError("Pick at least one filter.");
        return;
    }

    setLastError("");
    setLoading(true);

    QNetworkRequest request(buildSearchUrlAdvanced(cleanName, cleanTag, cleanCountry, cleanLanguage));
    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { onStationsReplyFinished(reply); });
}

void RadioController::refreshFilters()
{
    requestFilterList("tags", "tags");
    requestFilterList("countries", "countries");

    // Hardcoded language groups instead of fetching the full raw list
    setFilterList("languages", {"English", "Arabic", "Japanese", "Chinese"});
}

void RadioController::playStation(int index)
{
    const RadioStation *station = m_model->stationAt(index);
    if (!station || station->streamUrl.isEmpty()) {
        setLastError("Station stream not available.");
        return;
    }

    setSelectedIndex(index);
    m_stationName = station->name.isEmpty() ? "Unknown Station" : station->name;
    emit stationChanged();

    setNowPlaying(m_stationName);
    setLastError("");

    m_player->setSource(QUrl(station->streamUrl));
    m_player->play();
}

void RadioController::play()
{
    if (m_player->source().isEmpty() && m_selectedIndex >= 0) {
        playStation(m_selectedIndex);
        return;
    }
    m_player->play();
}

void RadioController::pause()
{
    m_player->pause();
}

void RadioController::stop()
{
    m_player->stop();
    setPlaybackStatus("stopped");
}

void RadioController::setVolume(int volume)
{
    int safeVol = qBound(0, volume, 100);
    if (m_volume == safeVol) return;
    m_volume = safeVol;
    m_audio->setVolume(m_volume / 100.0);
    emit volumeChanged();
}

void RadioController::setSelectedIndex(int index)
{
    if (m_selectedIndex == index) return;
    m_selectedIndex = index;
    emit selectedIndexChanged();
}

void RadioController::onStationsReplyFinished(QNetworkReply *reply)
{
    setLoading(false);

    QByteArray payload = reply->readAll();
    QNetworkReply::NetworkError netError = reply->error();
    QString errorText = reply->errorString();
    QVariant statusAttr = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);
    int statusCode = statusAttr.isValid() ? statusAttr.toInt() : 0;
    reply->deleteLater();

    if (netError != QNetworkReply::NoError) {
        if (statusCode > 0) {
            setLastError(QString("RadioBrowser request failed (%1): %2").arg(statusCode).arg(errorText));
        } else {
            setLastError(QString("RadioBrowser request failed: %1").arg(errorText));
        }
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isArray()) {
        setLastError("Unexpected response from RadioBrowser.");
        return;
    }

    QVector<RadioStation> stations;
    QJsonArray array = doc.array();
    stations.reserve(array.size());

    for (const QJsonValue &value : array) {
        QJsonObject obj = value.toObject();
        RadioStation station;
        station.stationId = obj.value("stationuuid").toString();
        station.name = obj.value("name").toString();
        station.streamUrl = obj.value("url_resolved").toString();
        if (station.streamUrl.isEmpty()) station.streamUrl = obj.value("url").toString();
        station.favicon = obj.value("favicon").toString();
        station.tags = obj.value("tags").toString();
        station.country = obj.value("country").toString();
        station.language = obj.value("language").toString();
        station.codec = obj.value("codec").toString();
        station.bitrate = obj.value("bitrate").toInt();
        if (!station.streamUrl.isEmpty()) stations.push_back(station);
    }

    m_model->setStations(stations);
    if (stations.isEmpty()) {
        setLastError("No stations found for the selected filters.");
    }
    setSelectedIndex(-1);
}

void RadioController::onFilterListReplyFinished(QNetworkReply *reply)
{
    QString propertyKey = reply->property("filterKey").toString();
    QByteArray payload = reply->readAll();
    reply->deleteLater();

    if (propertyKey.isEmpty() || reply->error() != QNetworkReply::NoError) return;

    QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isArray()) return;

    QStringList values;
    QJsonArray array = doc.array();
    values.reserve(array.size());

    for (const QJsonValue &value : array) {
        QString name = value.toObject().value("name").toString();
        if (!name.trimmed().isEmpty()) values.append(name.trimmed());
    }

    values.removeDuplicates();
    std::sort(values.begin(), values.end(), [](const QString &a, const QString &b) {
        return a.toLower() < b.toLower();
    });

    values.prepend("Any");
    setFilterList(propertyKey, values);
}

void RadioController::handlePlaybackState()
{
    switch (m_player->playbackState()) {
    case QMediaPlayer::PlayingState:
        setPlaybackStatus("playing");
        break;
    case QMediaPlayer::PausedState:
        setPlaybackStatus("paused");
        break;
    case QMediaPlayer::StoppedState:
        setPlaybackStatus("stopped");
        break;
    }
}

void RadioController::handleMediaStatusChanged(QMediaPlayer::MediaStatus status)
{
    bool loading = (status == QMediaPlayer::LoadingMedia || status == QMediaPlayer::BufferingMedia);
    setLoading(loading);
}

void RadioController::handleMetaDataChanged()
{
    updateNowPlaying();
}

void RadioController::handleError(QMediaPlayer::Error error, const QString &errorString)
{
    Q_UNUSED(error)
    setLastError(errorString.isEmpty() ? "Playback error." : errorString);
}

void RadioController::setLoading(bool loading)
{
    if (m_loading == loading) return;
    m_loading = loading;
    emit loadingChanged();
}

void RadioController::setPlaybackStatus(const QString &status)
{
    if (m_playbackStatus == status) return;
    m_playbackStatus = status;
    emit playbackStatusChanged();
}

void RadioController::setNowPlaying(const QString &title)
{
    QString next = title.trimmed().isEmpty() ? m_stationName : title.trimmed();
    if (m_nowPlaying == next) return;
    m_nowPlaying = next;
    emit nowPlayingChanged();
}

void RadioController::updateNowPlaying()
{
    QString metaTitle = m_player->metaData().stringValue(QMediaMetaData::Title);
    if (metaTitle.trimmed().isEmpty()) {
        setNowPlaying(m_stationName.isEmpty() ? "No station" : m_stationName);
    } else {
        setNowPlaying(metaTitle);
    }
}

void RadioController::setLastError(const QString &error)
{
    if (m_lastError == error) return;
    m_lastError = error;
    emit errorChanged();
}

QUrl RadioController::buildSearchUrl(const QString &filter, const QString &value) const
{
    QUrl url(m_apiBase + "/stations/search");
    QUrlQuery query;

    query.addQueryItem("order", "clickcount");
    query.addQueryItem("reverse", "true");
    query.addQueryItem("limit", "50");

    QString normalized = filter.trimmed().toLower();
    if (normalized == "station name" || normalized == "name") {
        query.addQueryItem("name", value);
    } else if (normalized == "tags" || normalized == "tag") {
        query.addQueryItem("tag", value);
    } else if (normalized == "country") {
        query.addQueryItem("country", value);
    } else if (normalized == "language") {
        query.addQueryItem("language", value);
    } else {
        query.addQueryItem("name", value);
    }

    url.setQuery(query);
    return url;
}

QUrl RadioController::buildSearchUrlAdvanced(const QString &name, const QString &tag, const QString &country, const QString &language) const
{
    QUrl url(m_apiBase + "/stations/search");
    QUrlQuery query;

    query.addQueryItem("order", "clickcount");
    query.addQueryItem("reverse", "true");
    query.addQueryItem("limit", "50");

    QString cleanName = name.trimmed();
    QString cleanTag = normalizedFilterValue(tag);
    QString cleanCountry = normalizedFilterValue(country);
    QString cleanLanguage = normalizedLanguageValue(language);

    if (!cleanName.isEmpty()) query.addQueryItem("name", cleanName);
    if (!cleanTag.isEmpty()) query.addQueryItem("tag", cleanTag);
    if (!cleanCountry.isEmpty()) query.addQueryItem("country", cleanCountry);
    if (!cleanLanguage.isEmpty()) query.addQueryItem("language", cleanLanguage);

    url.setQuery(query);
    return url;
}

void RadioController::requestFilterList(const QString &endpoint, const QString &propertyKey)
{
    QNetworkRequest request(QUrl(m_apiBase + "/" + endpoint));
    QNetworkReply *reply = m_nam->get(request);
    reply->setProperty("filterKey", propertyKey);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { onFilterListReplyFinished(reply); });
}

void RadioController::setFilterList(const QString &propertyKey, const QStringList &values)
{
    if (propertyKey == "tags") {
        if (m_tags == values) return;
        m_tags = values;
        emit tagsChanged();
    } else if (propertyKey == "countries") {
        if (m_countries == values) return;
        m_countries = values;
        emit countriesChanged();
    } else if (propertyKey == "languages") {
        if (m_languages == values) return;
        m_languages = values;
        emit languagesChanged();
    }
}

QString RadioController::normalizedFilterValue(const QString &value) const
{
    QString trimmed = value.trimmed();
    if (trimmed.isEmpty() || trimmed.toLower() == "any") return "";
    return trimmed;
}

QString RadioController::normalizedLanguageValue(const QString &value) const
{
    QString trimmed = value.trimmed();
    if (trimmed.isEmpty() || trimmed.toLower() == "any") return "";

    QString lower = trimmed.toLower();
    if (lower == "english") return "english";
    if (lower == "arabic")  return "arabic";
    if (lower == "japanese") return "japanese";
    if (lower == "chinese") return "chinese";

    return trimmed;
}
