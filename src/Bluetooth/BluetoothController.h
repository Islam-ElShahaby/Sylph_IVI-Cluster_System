#ifndef BLUETOOTHCONTROLLER_H
#define BLUETOOTHCONTROLLER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QAbstractListModel>
#include <QVector>

#if defined(Q_OS_LINUX)
#include <QtDBus/QDBusContext>
#include <QtDBus/QDBusMessage>
#include <QtDBus/QDBusConnection>
#endif

// Forward declare our abstract backend interface
class IBluetoothBackend;
// BlueZ pairing agent (org.bluez.Agent1) -- defined in the .cpp (Linux only)
class BluezAgent;

// A bonded (paired) Bluetooth device
struct BtDevice {
    QString name;
    QString address;
    QString path;     // BlueZ object path
    bool connected = false;
};

class BluetoothDevicesModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum DeviceRole {
        NameRole = Qt::UserRole + 1,
        AddressRole,
        ConnectedRole,
        PathRole
    };

    explicit BluetoothDevicesModel(QObject *parent = nullptr) : QAbstractListModel(parent) {}

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setDevices(const QVector<BtDevice> &devices);

private:
    QVector<BtDevice> m_devices;
};

class BluetoothController : public QObject
#if defined(Q_OS_LINUX)
    // The registered D-Bus object owns the call context (QDBusContext), so the
    // pairing agent's delayed reply must be driven from here, not the adaptor.
    , protected QDBusContext
#endif
{
    Q_OBJECT
    Q_PROPERTY(QString trackTitle READ trackTitle NOTIFY metadataChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY metadataChanged)
    Q_PROPERTY(QString album READ album NOTIFY metadataChanged)
    Q_PROPERTY(QString playbackStatus READ playbackStatus NOTIFY statusChanged)
    Q_PROPERTY(uint position READ position NOTIFY positionChanged)
    Q_PROPERTY(uint duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(QString coverArt READ coverArt NOTIFY coverArtChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString deviceName READ deviceName WRITE setDeviceName NOTIFY deviceNameChanged)
    Q_PROPERTY(bool discoverable READ discoverable WRITE setDiscoverable NOTIFY discoverableChanged)
    Q_PROPERTY(QAbstractListModel* pairedDevices READ pairedDevices CONSTANT)

public:
    explicit BluetoothController(QObject *parent = nullptr);
    ~BluetoothController();

    QString trackTitle() const { return m_trackTitle; }
    QString artist() const { return m_artist; }
    QString album() const { return m_album; }
    QString playbackStatus() const { return m_playbackStatus; }
    uint position() const { return m_position; }
    uint duration() const { return m_duration; }
    QString coverArt() const { return m_coverArt; }
    int volume() const { return m_volume; }
    bool connected() const { return m_connected; }
    bool enabled() const { return m_enabled; }
    QString deviceName() const { return m_deviceName; }
    bool discoverable() const { return m_discoverable; }
    QAbstractListModel *pairedDevices() { return m_devicesModel; }

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void fastForward();
    Q_INVOKABLE void rewind();
    Q_INVOKABLE void updatePosition(uint ms);
    Q_INVOKABLE void setVolume(int vol);
    Q_INVOKABLE void setEnabled(bool enabled);
    Q_INVOKABLE void setDeviceName(const QString &name);
    Q_INVOKABLE void setDiscoverable(bool discoverable);
    Q_INVOKABLE void refreshEnabled();

    // Paired (bonded) devices -- the car lists what's bonded, it doesn't scan.
    Q_INVOKABLE void refreshPairedDevices();
    Q_INVOKABLE void connectDevice(const QString &path);
    Q_INVOKABLE void disconnectDevice(const QString &path);
    Q_INVOKABLE void forgetDevice(const QString &path);

    // Pairing: confirm (or reject) the in-flight numeric-comparison request.
    Q_INVOKABLE void confirmPairing(bool accept);

    // Called by the BlueZ agent (during the D-Bus dispatch) to capture the
    // delayed reply and surface / dismiss the pairing request.
    void beginPairingConfirm(const QString &devicePath, quint32 passkey);
    void cancelPairing();
    QString deviceAlias(const QString &devicePath) const;

    // Internal Setters used by the OS-specific Backends
    void setTrackData(const QString &title, const QString &artist, const QString &album, uint duration);
    void setPlaybackStatus(const QString &status);
    void setPositionInternal(uint pos);
    void setVolumeInternal(int vol);
    void setConnectedStatus(bool connected);

signals:
    void metadataChanged();
    void statusChanged();
    void positionChanged();
    void durationChanged();
    void coverArtChanged();
    void volumeChanged();
    void connectedChanged();
    void enabledChanged();
    void deviceNameChanged();
    void discoverableChanged();

    // A device is trying to pair -- show a popup with the numeric code so the
    // user can compare it against the code on their phone, then confirm.
    void pairingRequested(const QString &deviceName, const QString &passkey);
    void pairingCancelled();

private slots:
    void onCoverArtSearchFinished(QNetworkReply *reply);
    void onCoverArtDownloaded(QNetworkReply *reply);

private:
    QString coverCacheKey(const QString &title, const QString &artist) const;
    QString coverCacheFilePath(const QString &key) const;
    void setCoverArtPlaceholder();
    void fetchCoverArt(const QString &title, const QString &artist);
    void manageCacheSize();
    bool updateAdapterPowered();
    bool setAdapterPowered(bool enabled);
    QString resolveAdapterPath();
    void setupAgent();
    void updateAdapterInfo();    // read Alias + Discoverable from BlueZ
    void applyAdapterDefaults(); // pairable + discoverable
    void attemptPowerOn(int attempt); // retrying power-on after rfkill unblock

    QNetworkAccessManager *m_nam;
    IBluetoothBackend *m_backend; // OS-specific implementation
    BluezAgent *m_agent = nullptr; // pairing agent (Linux/BlueZ only)
    BluetoothDevicesModel *m_devicesModel; // bonded devices

    QString m_trackTitle = "No Track";
    QString m_artist = "";
    QString m_album = "";
    QString m_playbackStatus = "stopped";
    uint m_position = 0;
    uint m_duration = 0;
    QString m_coverArt = "qrc:/cover_placeholder.png";
    int m_volume = 100;
    bool m_connected = false;
    bool m_enabled = true;
    QString m_deviceName;
    bool m_discoverable = false;
    QString m_adapterPath;
    QString m_lastFetchedKey;
    QString m_pendingCoverKey;

#if defined(Q_OS_LINUX)
    // In-flight pairing reply (held until the user confirms/rejects)
    QDBusMessage m_pendingMsg;
    QDBusConnection m_pendingConn = QDBusConnection::systemBus();
    bool m_hasPendingPair = false;
#endif
};

#endif // BLUETOOTHCONTROLLER_H
