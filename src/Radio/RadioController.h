#ifndef RADIOCONTROLLER_H
#define RADIOCONTROLLER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QStringList>
#include "RadioStationsModel.h"

class RadioController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractListModel* stationsModel READ stationsModel CONSTANT)
    Q_PROPERTY(QStringList tags READ tags NOTIFY tagsChanged)
    Q_PROPERTY(QStringList countries READ countries NOTIFY countriesChanged)
    Q_PROPERTY(QStringList languages READ languages NOTIFY languagesChanged)
    Q_PROPERTY(QString stationName READ stationName NOTIFY stationChanged)
    Q_PROPERTY(QString nowPlaying READ nowPlaying NOTIFY nowPlayingChanged)
    Q_PROPERTY(QString playbackStatus READ playbackStatus NOTIFY playbackStatusChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(int selectedIndex READ selectedIndex NOTIFY selectedIndexChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)

public:
    explicit RadioController(QObject *parent = nullptr);

    QAbstractListModel *stationsModel() { return m_model; }
    QString stationName() const { return m_stationName; }
    QStringList tags() const { return m_tags; }
    QStringList countries() const { return m_countries; }
    QStringList languages() const { return m_languages; }
    QString nowPlaying() const { return m_nowPlaying; }
    QString playbackStatus() const { return m_playbackStatus; }
    bool loading() const { return m_loading; }
    int volume() const { return m_volume; }
    int selectedIndex() const { return m_selectedIndex; }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE void searchStations(const QString &filter, const QString &value);
    Q_INVOKABLE void searchStationsAdvanced(const QString &name, const QString &tag, const QString &country, const QString &language);
    Q_INVOKABLE void refreshFilters();
    Q_INVOKABLE void playStation(int index);
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void setVolume(int volume);
    Q_INVOKABLE void setSelectedIndex(int index);

signals:
    void tagsChanged();
    void countriesChanged();
    void languagesChanged();
    void stationChanged();
    void nowPlayingChanged();
    void playbackStatusChanged();
    void loadingChanged();
    void volumeChanged();
    void selectedIndexChanged();
    void errorChanged();

private slots:
    void onStationsReplyFinished(QNetworkReply *reply);
    void onFilterListReplyFinished(QNetworkReply *reply);
    void handlePlaybackState();
    void handleMediaStatusChanged(QMediaPlayer::MediaStatus status);
    void handleMetaDataChanged();
    void handleError(QMediaPlayer::Error error, const QString &errorString);

private:
    void setLoading(bool loading);
    void setPlaybackStatus(const QString &status);
    void setNowPlaying(const QString &title);
    void updateNowPlaying();
    void setLastError(const QString &error);
    QUrl buildSearchUrl(const QString &filter, const QString &value) const;
    QUrl buildSearchUrlAdvanced(const QString &name, const QString &tag, const QString &country, const QString &language) const;
    void requestFilterList(const QString &endpoint, const QString &propertyKey);
    void setFilterList(const QString &propertyKey, const QStringList &values);
    QString normalizedFilterValue(const QString &value) const;
    QString normalizedLanguageValue(const QString &value) const;

    QNetworkAccessManager *m_nam;
    RadioStationsModel *m_model;
    QMediaPlayer *m_player;
    QAudioOutput *m_audio;

    QString m_stationName;
    QString m_nowPlaying;
    QString m_playbackStatus = "stopped";
    bool m_loading = false;
    int m_volume = 80;
    int m_selectedIndex = -1;
    QString m_lastError;
    QStringList m_tags;
    QStringList m_countries;
    QStringList m_languages;

    const QString m_apiBase = "https://de1.api.radio-browser.info/json";
};

#endif // RADIOCONTROLLER_H
