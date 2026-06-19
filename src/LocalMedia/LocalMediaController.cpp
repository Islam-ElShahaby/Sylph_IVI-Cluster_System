#include "LocalMediaController.h"
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QDirIterator>
#include <QMediaMetaData>
#include <QRandomGenerator>
#include <QFile>
#include <QDebug>

// ============================================================================
// LocalTracksModel Implementation
// ============================================================================

LocalTracksModel::LocalTracksModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int LocalTracksModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_tracks.size();
}

QVariant LocalTracksModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_tracks.size())
        return QVariant();

    const LocalTrack &track = m_tracks.at(index.row());
    switch (role) {
    case TitleRole:    return track.title;
    case ArtistRole:   return track.artist;
    case AlbumRole:    return track.album;
    case FilePathRole: return track.filePath;
    case FileNameRole: return track.fileName;
    case SourceRole:   return track.source;
    case IsSavedRole:  return track.isSaved;
    default:           return QVariant();
    }
}

QHash<int, QByteArray> LocalTracksModel::roleNames() const
{
    return {
        { TitleRole,    "title" },
        { ArtistRole,   "artist" },
        { AlbumRole,    "album" },
        { FilePathRole, "filePath" },
        { FileNameRole, "fileName" },
        { SourceRole,   "source" },
        { IsSavedRole,  "isSaved" }
    };
}

void LocalTracksModel::setTracks(const QVector<LocalTrack> &tracks)
{
    beginResetModel();
    m_tracks = tracks;
    endResetModel();
}

const LocalTrack *LocalTracksModel::trackAt(int index) const
{
    if (index < 0 || index >= m_tracks.size()) return nullptr;
    return &m_tracks.at(index);
}

void LocalTracksModel::markSaved(int index, const QString &newPath)
{
    if (index < 0 || index >= m_tracks.size()) return;
    m_tracks[index].source = "local";
    m_tracks[index].isSaved = true;
    m_tracks[index].filePath = newPath;
    emit dataChanged(this->index(index), this->index(index), { SourceRole, IsSavedRole, FilePathRole });
}

void LocalTracksModel::clear()
{
    beginResetModel();
    m_tracks.clear();
    endResetModel();
}

// ============================================================================
// LocalMediaController Implementation
// ============================================================================

LocalMediaController::LocalMediaController(QObject *parent)
    : QObject(parent)
    , m_model(new LocalTracksModel(this))
    , m_player(new QMediaPlayer(this))
    , m_audio(new QAudioOutput(this))
{
    m_audio->setVolume(m_volume / 100.0);
    m_player->setAudioOutput(m_audio);

    connect(m_player, &QMediaPlayer::playbackStateChanged,
            this, &LocalMediaController::handlePlaybackState);
    connect(m_player, &QMediaPlayer::mediaStatusChanged,
            this, &LocalMediaController::handleMediaStatusChanged);
    connect(m_player, &QMediaPlayer::metaDataChanged,
            this, &LocalMediaController::handleMetaDataChanged);
    connect(m_player, &QMediaPlayer::errorOccurred,
            this, &LocalMediaController::handleError);
    connect(m_player, &QMediaPlayer::durationChanged,
            this, &LocalMediaController::handleDurationChanged);
    connect(m_player, &QMediaPlayer::positionChanged,
            this, &LocalMediaController::handlePositionChanged);

    // Ensure local music directory exists
    QDir().mkpath(localMusicDir());
}

int LocalMediaController::trackCount() const
{
    return m_model->count();
}

QString LocalMediaController::localMusicDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::MusicLocation) + "/Sylph";
}

QStringList LocalMediaController::audioFileFilters() const
{
    return {
        "*.mp3", "*.flac", "*.wav", "*.ogg",
        "*.m4a", "*.aac", "*.wma"
    };
}

// ============================================================================
// Media Scanning
// ============================================================================

void LocalMediaController::scanMedia()
{
    setScanning(true);
    setLastError("");

    QVector<LocalTrack> allTracks;

    // 1. Scan local music directory
    QString localDir = localMusicDir();
    if (QDir(localDir).exists()) {
        scanDirectory(localDir, "local", allTracks);
    }

    // 2. Scan USB mount points
#if defined(Q_OS_LINUX) || defined(Q_OS_QNX)

#if defined(Q_OS_QNX)
    // QNX: USB devices mount under /fs/usb*
    QDir fsDir("/fs");
    if (fsDir.exists()) {
        QStringList usbDirs = fsDir.entryList(QStringList() << "usb*", QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &usb : usbDirs) {
            scanDirectory("/fs/" + usb, "usb", allTracks);
        }
    }
#else
    // Linux: USB devices mount under /media/$USER or /run/media/$USER
    QStringList usbRoots;
    QString user = qEnvironmentVariable("USER");

    QDir mediaDir("/media/" + user);
    if (mediaDir.exists()) {
        for (const QString &vol : mediaDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            usbRoots << mediaDir.absoluteFilePath(vol);
        }
    }
    QDir mediaRoot("/media");
    if (mediaRoot.exists() && user.isEmpty()) {
        for (const QString &vol : mediaRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            usbRoots << mediaRoot.absoluteFilePath(vol);
        }
    }
    QDir runMediaDir("/run/media/" + user);
    if (runMediaDir.exists()) {
        for (const QString &vol : runMediaDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            usbRoots << runMediaDir.absoluteFilePath(vol);
        }
    }

    for (const QString &root : usbRoots) {
        scanDirectory(root, "usb", allTracks);
    }
#endif

#else
    // Mock/Desktop: scan a demo folder in user's Music directory
    QString demoUsb = QStandardPaths::writableLocation(QStandardPaths::MusicLocation) + "/SylphUSB";
    if (QDir(demoUsb).exists()) {
        scanDirectory(demoUsb, "usb", allTracks);
    }
#endif

    m_model->setTracks(allTracks);
    emit trackCountChanged();

    if (allTracks.isEmpty()) {
        setLastError("No audio files found.");
    }

    setScanning(false);
}

void LocalMediaController::scanDirectory(const QString &dirPath, const QString &source,
                                          QVector<LocalTrack> &results)
{
    QDirIterator it(dirPath, audioFileFilters(),
                    QDir::Files | QDir::Readable,
                    QDirIterator::Subdirectories);

    while (it.hasNext()) {
        it.next();
        QFileInfo fi = it.fileInfo();

        LocalTrack track;
        track.filePath = fi.absoluteFilePath();
        track.fileName = fi.fileName();
        track.source = source;
        track.isSaved = (source == "local");

        // Use filename without extension as a fallback title
        track.title = fi.completeBaseName();
        track.artist = "";
        track.album = "";

        results.append(track);
    }
}

// ============================================================================
// Playback Controls
// ============================================================================

void LocalMediaController::playTrack(int index)
{
    const LocalTrack *track = m_model->trackAt(index);
    if (!track || track->filePath.isEmpty()) {
        setLastError("Track not available.");
        return;
    }

    if (m_currentIndex != index) {
        m_currentIndex = index;
        emit currentIndexChanged();
    }

    m_currentTitle = track->title.isEmpty() ? track->fileName : track->title;
    m_currentArtist = track->artist;
    m_currentAlbum = track->album;
    emit metadataChanged();

    setLastError("");
    m_position = 0;
    emit positionChanged();

    m_player->setSource(QUrl::fromLocalFile(track->filePath));
    m_player->play();

    // Add to shuffle history
    if (m_shuffle) {
        // Trim any forward history if we navigated back and then played a new track
        if (m_shuffleHistoryPos >= 0 && m_shuffleHistoryPos < m_shuffleHistory.size() - 1) {
            m_shuffleHistory.resize(m_shuffleHistoryPos + 1);
        }
        m_shuffleHistory.append(index);
        m_shuffleHistoryPos = m_shuffleHistory.size() - 1;
    }
}

void LocalMediaController::play()
{
    if (m_player->source().isEmpty() && m_currentIndex >= 0) {
        playTrack(m_currentIndex);
        return;
    }
    if (m_player->source().isEmpty() && m_model->count() > 0) {
        playTrack(m_shuffle ? pickNextShuffleIndex() : 0);
        return;
    }
    m_player->play();
}

void LocalMediaController::pause()
{
    m_player->pause();
}

void LocalMediaController::stop()
{
    m_player->stop();
    setPlaybackStatus("stopped");
}

void LocalMediaController::next()
{
    if (m_model->count() == 0) return;

    if (m_shuffle) {
        // If we have forward history from previous back-navigation, use it
        if (m_shuffleHistoryPos >= 0 && m_shuffleHistoryPos < m_shuffleHistory.size() - 1) {
            m_shuffleHistoryPos++;
            playTrack(m_shuffleHistory[m_shuffleHistoryPos]);
            return;
        }
        playTrack(pickNextShuffleIndex());
    } else {
        int nextIdx = (m_currentIndex + 1) % m_model->count();
        playTrack(nextIdx);
    }
}

void LocalMediaController::previous()
{
    if (m_model->count() == 0) return;

    // If we're more than 3 seconds in, restart the current track
    if (m_position > 3000) {
        m_player->setPosition(0);
        return;
    }

    if (m_shuffle) {
        if (m_shuffleHistoryPos > 0) {
            m_shuffleHistoryPos--;
            playTrack(m_shuffleHistory[m_shuffleHistoryPos]);
            return;
        }
    }

    int prevIdx = (m_currentIndex - 1 + m_model->count()) % m_model->count();
    playTrack(prevIdx);
}

void LocalMediaController::setVolume(int vol)
{
    int safeVol = qBound(0, vol, 100);
    if (m_volume == safeVol) return;
    m_volume = safeVol;
    m_audio->setVolume(m_volume / 100.0);
    emit volumeChanged();
}

void LocalMediaController::setShuffle(bool enabled)
{
    if (m_shuffle == enabled) return;
    m_shuffle = enabled;
    m_shuffleHistory.clear();
    m_shuffleHistoryPos = -1;
    if (enabled && m_currentIndex >= 0) {
        m_shuffleHistory.append(m_currentIndex);
        m_shuffleHistoryPos = 0;
    }
    emit shuffleChanged();
}

void LocalMediaController::updatePosition(uint ms)
{
    if (m_playbackStatus == "playing") {
        m_position += ms;
        if (m_duration > 0 && m_position > m_duration) m_position = m_duration;
        emit positionChanged();
    }
}

int LocalMediaController::pickNextShuffleIndex()
{
    if (m_model->count() <= 1) return 0;

    int next;
    do {
        next = QRandomGenerator::global()->bounded(m_model->count());
    } while (next == m_currentIndex && m_model->count() > 1);

    return next;
}

// ============================================================================
// Save USB Track to Local
// ============================================================================

void LocalMediaController::saveToLocal(int index)
{
    const LocalTrack *track = m_model->trackAt(index);
    if (!track) {
        setLastError("Invalid track index.");
        return;
    }
    if (track->source == "local" || track->isSaved) {
        return; // Already local
    }

    QString destDir = localMusicDir();
    QDir().mkpath(destDir);

    QString destPath = destDir + "/" + track->fileName;

    // Handle filename collision
    if (QFile::exists(destPath)) {
        QFileInfo fi(track->fileName);
        QString base = fi.completeBaseName();
        QString ext = fi.suffix();
        int counter = 1;
        do {
            destPath = destDir + "/" + base + "_" + QString::number(counter) + "." + ext;
            counter++;
        } while (QFile::exists(destPath));
    }

    if (QFile::copy(track->filePath, destPath)) {
        m_model->markSaved(index, destPath);
        emit trackSaved(index);
        qDebug() << "Saved to local:" << destPath;
    } else {
        setLastError("Failed to copy file to local library.");
    }
}

// ============================================================================
// QMediaPlayer Signal Handlers
// ============================================================================

void LocalMediaController::handlePlaybackState()
{
    switch (m_player->playbackState()) {
    case QMediaPlayer::PlayingState:
        setPlaybackStatus("playing");
        break;
    case QMediaPlayer::PausedState:
        setPlaybackStatus("paused");
        break;
    case QMediaPlayer::StoppedState:
        // When a track finishes naturally, auto-advance to next
        if (m_playbackStatus == "playing" && m_duration > 0 && m_position >= m_duration - 1500) {
            next();
        } else {
            setPlaybackStatus("stopped");
        }
        break;
    }
}

void LocalMediaController::handleMediaStatusChanged(QMediaPlayer::MediaStatus status)
{
    if (status == QMediaPlayer::EndOfMedia) {
        next();
    }
}

void LocalMediaController::handleMetaDataChanged()
{
    QMediaMetaData meta = m_player->metaData();
    QString title = meta.stringValue(QMediaMetaData::Title);
    QString artist = meta.stringValue(QMediaMetaData::ContributingArtist);
    if (artist.isEmpty())
        artist = meta.stringValue(QMediaMetaData::AlbumArtist);
    QString album = meta.stringValue(QMediaMetaData::AlbumTitle);

    bool changed = false;
    if (!title.isEmpty() && title != m_currentTitle) {
        m_currentTitle = title;
        changed = true;
    }
    if (!artist.isEmpty() && artist != m_currentArtist) {
        m_currentArtist = artist;
        changed = true;
    }
    if (!album.isEmpty() && album != m_currentAlbum) {
        m_currentAlbum = album;
        changed = true;
    }
    if (changed) emit metadataChanged();
}

void LocalMediaController::handleError(QMediaPlayer::Error error, const QString &errorString)
{
    Q_UNUSED(error)
    setLastError(errorString.isEmpty() ? "Playback error." : errorString);
}

void LocalMediaController::handleDurationChanged(qint64 dur)
{
    uint d = static_cast<uint>(dur);
    if (m_duration != d) {
        m_duration = d;
        emit durationChanged();
    }
}

void LocalMediaController::handlePositionChanged(qint64 pos)
{
    uint p = static_cast<uint>(pos);
    if (m_position != p) {
        m_position = p;
        emit positionChanged();
    }
}

// ============================================================================
// Internal Setters
// ============================================================================

void LocalMediaController::setPlaybackStatus(const QString &status)
{
    if (m_playbackStatus == status) return;
    m_playbackStatus = status;
    emit playbackStatusChanged();
}

void LocalMediaController::setLastError(const QString &error)
{
    if (m_lastError == error) return;
    m_lastError = error;
    emit errorChanged();
}

void LocalMediaController::setScanning(bool scanning)
{
    if (m_scanning == scanning) return;
    m_scanning = scanning;
    emit scanningChanged();
}
