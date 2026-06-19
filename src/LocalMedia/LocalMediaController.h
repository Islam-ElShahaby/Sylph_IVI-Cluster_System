#ifndef LOCALMEDIACONTROLLER_H
#define LOCALMEDIACONTROLLER_H

#include <QObject>
#include <QAbstractListModel>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QVector>
#include <QString>
#include <QStringList>

// ============================================================================
// Track data structure
// ============================================================================
struct LocalTrack {
    QString title;
    QString artist;
    QString album;
    QString filePath;
    QString fileName;
    QString source;   // "usb" or "local"
    bool isSaved = false;
};

// ============================================================================
// List model for QML ListView
// ============================================================================
class LocalTracksModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum TrackRole {
        TitleRole = Qt::UserRole + 1,
        ArtistRole,
        AlbumRole,
        FilePathRole,
        FileNameRole,
        SourceRole,
        IsSavedRole
    };

    explicit LocalTracksModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setTracks(const QVector<LocalTrack> &tracks);
    const LocalTrack *trackAt(int index) const;
    void markSaved(int index, const QString &newPath);
    void clear();
    int count() const { return m_tracks.size(); }

private:
    QVector<LocalTrack> m_tracks;
};

// ============================================================================
// Controller singleton exposed to QML
// ============================================================================
class LocalMediaController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractListModel* tracksModel READ tracksModel CONSTANT)
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY metadataChanged)
    Q_PROPERTY(QString currentArtist READ currentArtist NOTIFY metadataChanged)
    Q_PROPERTY(QString currentAlbum READ currentAlbum NOTIFY metadataChanged)
    Q_PROPERTY(QString playbackStatus READ playbackStatus NOTIFY playbackStatusChanged)
    Q_PROPERTY(uint position READ position NOTIFY positionChanged)
    Q_PROPERTY(uint duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool shuffle READ shuffle WRITE setShuffle NOTIFY shuffleChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)
    Q_PROPERTY(int trackCount READ trackCount NOTIFY trackCountChanged)

public:
    explicit LocalMediaController(QObject *parent = nullptr);

    QAbstractListModel *tracksModel() { return m_model; }
    QString currentTitle() const { return m_currentTitle; }
    QString currentArtist() const { return m_currentArtist; }
    QString currentAlbum() const { return m_currentAlbum; }
    QString playbackStatus() const { return m_playbackStatus; }
    uint position() const { return m_position; }
    uint duration() const { return m_duration; }
    int volume() const { return m_volume; }
    int currentIndex() const { return m_currentIndex; }
    bool scanning() const { return m_scanning; }
    bool shuffle() const { return m_shuffle; }
    QString lastError() const { return m_lastError; }
    int trackCount() const;

    Q_INVOKABLE void scanMedia();
    Q_INVOKABLE void playTrack(int index);
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void setVolume(int vol);
    Q_INVOKABLE void setShuffle(bool enabled);
    Q_INVOKABLE void saveToLocal(int index);
    Q_INVOKABLE void updatePosition(uint ms);

signals:
    void metadataChanged();
    void playbackStatusChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void currentIndexChanged();
    void scanningChanged();
    void shuffleChanged();
    void errorChanged();
    void trackCountChanged();
    void trackSaved(int index);

private slots:
    void handlePlaybackState();
    void handleMediaStatusChanged(QMediaPlayer::MediaStatus status);
    void handleMetaDataChanged();
    void handleError(QMediaPlayer::Error error, const QString &errorString);
    void handleDurationChanged(qint64 dur);
    void handlePositionChanged(qint64 pos);

private:
    void setPlaybackStatus(const QString &status);
    void setLastError(const QString &error);
    void setScanning(bool scanning);
    QString localMusicDir() const;
    QStringList audioFileFilters() const;
    void scanDirectory(const QString &dirPath, const QString &source, QVector<LocalTrack> &results);
    int pickNextShuffleIndex();

    LocalTracksModel *m_model;
    QMediaPlayer *m_player;
    QAudioOutput *m_audio;

    QString m_currentTitle = "No Track";
    QString m_currentArtist;
    QString m_currentAlbum;
    QString m_playbackStatus = "stopped";
    uint m_position = 0;
    uint m_duration = 0;
    int m_volume = 80;
    int m_currentIndex = -1;
    bool m_scanning = false;
    bool m_shuffle = false;
    QString m_lastError;

    QVector<int> m_shuffleHistory;
    int m_shuffleHistoryPos = -1;
};

#endif // LOCALMEDIACONTROLLER_H
