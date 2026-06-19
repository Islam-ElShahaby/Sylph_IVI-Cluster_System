#include "BluetoothController.h"
#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QUrl>
#include <QDateTime>
#include <functional>

// ============================================================================
// 1. ABSTRACT BACKEND INTERFACE
// ============================================================================
class IBluetoothBackend : public QObject {
public:
    IBluetoothBackend(BluetoothController *controller) : QObject(controller), m_controller(controller) {}
    virtual ~IBluetoothBackend() = default;

    virtual void play() = 0;
    virtual void pause() = 0;
    virtual void next() = 0;
    virtual void previous() = 0;
    virtual void fastForward() = 0;
    virtual void rewind() = 0;
    virtual void setVolume(int vol) = 0;

protected:
    BluetoothController *m_controller;
};

// ============================================================================
// 2. YOCTO / LINUX BACKEND (BlueZ & D-Bus)
// ============================================================================
#if defined(Q_OS_LINUX)
#include <QtDBus/QDBusInterface>
#include <QtDBus/QDBusReply>
#include <QtDBus/QDBusMessage>
#include <QtDBus/QDBusArgument>
#include <QtDBus/QDBusVariant>
#include <QtDBus/QDBusObjectPath>
#include <QtDBus/QDBusContext>
#include <QtDBus/QDBusAbstractAdaptor>
#include <QTimer>

class LinuxBluezBackend : public IBluetoothBackend {
    Q_OBJECT
public:
    LinuxBluezBackend(BluetoothController *controller) : IBluetoothBackend(controller) {
        if (!QDBusConnection::systemBus().isConnected()) {
            qWarning() << "Cannot connect to the D-Bus system bus";
            return;
        }

        QDBusConnection::systemBus().connect("org.bluez", "/", "org.freedesktop.DBus.ObjectManager",
                                             "InterfacesAdded", this, SLOT(scanForPlayer()));
        QDBusConnection::systemBus().connect("org.bluez", "/", "org.freedesktop.DBus.ObjectManager",
                                             "InterfacesRemoved", this, SLOT(scanForPlayer()));

        m_scanTimer = new QTimer(this);
        connect(m_scanTimer, &QTimer::timeout, this, &LinuxBluezBackend::scanForPlayer);
        m_scanTimer->start(5000);

        findActivePlayer();
    }

    void play() override { sendCmd("Play"); }
    void pause() override { sendCmd("Pause"); }
    void next() override { sendCmd("Next"); }
    void previous() override { sendCmd("Previous"); }
    void fastForward() override { sendCmd("FastForward"); }
    void rewind() override { sendCmd("Rewind"); }

    void setVolume(int vol) override {
        if (m_transportPath.isEmpty()) return;
        int btVol = qBound(0, qRound(vol * 127.0 / 100.0), 127);
        QDBusInterface transportProps("org.bluez", m_transportPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
        transportProps.call("Set", "org.bluez.MediaTransport1", "Volume",
                            QVariant::fromValue(QDBusVariant(QVariant::fromValue(static_cast<quint16>(btVol)))));
    }

private slots:
    void scanForPlayer() {
        if (m_playerPath.isEmpty() || !m_controller->connected()) findActivePlayer();
    }

    void handlePropertiesChanged(const QString &interface, const QVariantMap &changedProps, const QStringList &) {
        if (interface == "org.bluez.MediaTransport1") {
            if (changedProps.contains("Volume")) {
                m_controller->setVolumeInternal(qRound(changedProps["Volume"].toInt() * 100.0 / 127.0));
            }
            return;
        }
        if (changedProps.contains("Position")) {
            m_controller->setPositionInternal(changedProps["Position"].toUInt());
        }
        if (changedProps.contains("Status")) {
            m_controller->setPlaybackStatus(changedProps["Status"].toString());
            syncPosition();
        }
        if (changedProps.contains("Track")) {
            fetchTrackData();
            syncPosition();
        }
    }

private:
    void sendCmd(const QString &cmd) {
        if(m_playerPath.isEmpty()) return;
        QDBusMessage msg = QDBusMessage::createMethodCall("org.bluez", m_playerPath, "org.bluez.MediaPlayer1", cmd);
        QDBusConnection::systemBus().send(msg);
    }

    void syncPosition() {
        if (m_playerPath.isEmpty()) return;
        QDBusInterface props("org.bluez", m_playerPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
        QDBusReply<QVariant> rep = props.call("Get", "org.bluez.MediaPlayer1", "Position");
        if (rep.isValid()) m_controller->setPositionInternal(rep.value().toUInt());
    }

    void fetchTrackData() {
        if (m_playerPath.isEmpty()) return;
        QDBusInterface props("org.bluez", m_playerPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
        QDBusReply<QDBusVariant> rep = props.call("Get", "org.bluez.MediaPlayer1", "Track");
        if (rep.isValid()) {
            QVariantMap trackData = qdbus_cast<QVariantMap>(rep.value().variant());
            m_controller->setTrackData(
                trackData.value("Title").toString(),
                trackData.value("Artist").toString(),
                trackData.value("Album").toString(),
                trackData.value("Duration").toUInt()
                );
        }
    }

    void findActivePlayer() {
        QDBusMessage call = QDBusMessage::createMethodCall("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects");
        QDBusMessage reply = QDBusConnection::systemBus().call(call);
        if (reply.type() != QDBusMessage::ReplyMessage) return;

        QString foundPlayerPath, foundTransportPath;
        std::function<void(const QString&)> walkTree = [&](const QString &path) {
            QDBusMessage introMsg = QDBusMessage::createMethodCall("org.bluez", path, "org.freedesktop.DBus.Introspectable", "Introspect");
            QDBusMessage introReply = QDBusConnection::systemBus().call(introMsg);
            if (introReply.type() != QDBusMessage::ReplyMessage) return;
            QString xml = introReply.arguments().at(0).toString();

            if (xml.contains("org.bluez.MediaPlayer1")) foundPlayerPath = path;
            if (xml.contains("org.bluez.MediaTransport1")) foundTransportPath = path;

            int pos = 0;
            while ((pos = xml.indexOf("<node name=\"", pos)) != -1) {
                pos += 12;
                int end = xml.indexOf("\"", pos);
                if (end == -1) break;
                QString child = xml.mid(pos, end - pos);
                pos = end;
                walkTree((path == "/") ? "/" + child : path + "/" + child);
            }
        };

        walkTree("/org/bluez");

        if (foundPlayerPath.isEmpty()) {
            m_controller->setConnectedStatus(false);
            return;
        }

        if (m_playerPath != foundPlayerPath) {
            if (!m_playerPath.isEmpty()) QDBusConnection::systemBus().disconnect("org.bluez", m_playerPath, "org.freedesktop.DBus.Properties", "PropertiesChanged", this, SLOT(handlePropertiesChanged(QString, QVariantMap, QStringList)));
            m_playerPath = foundPlayerPath;
            QDBusConnection::systemBus().connect("org.bluez", m_playerPath, "org.freedesktop.DBus.Properties", "PropertiesChanged", this, SLOT(handlePropertiesChanged(QString, QVariantMap, QStringList)));
        }

        if (!foundTransportPath.isEmpty() && m_transportPath != foundTransportPath) {
            if (!m_transportPath.isEmpty()) QDBusConnection::systemBus().disconnect("org.bluez", m_transportPath, "org.freedesktop.DBus.Properties", "PropertiesChanged", this, SLOT(handlePropertiesChanged(QString, QVariantMap, QStringList)));
            m_transportPath = foundTransportPath;
            QDBusConnection::systemBus().connect("org.bluez", m_transportPath, "org.freedesktop.DBus.Properties", "PropertiesChanged", this, SLOT(handlePropertiesChanged(QString, QVariantMap, QStringList)));
        }

        m_controller->setConnectedStatus(true);
        fetchTrackData();
        syncPosition();

        QDBusInterface props("org.bluez", m_playerPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
        QDBusReply<QVariant> statusRep = props.call("Get", "org.bluez.MediaPlayer1", "Status");
        if (statusRep.isValid()) m_controller->setPlaybackStatus(statusRep.value().toString());
    }

    QTimer *m_scanTimer;
    QString m_playerPath;
    QString m_transportPath;
};

// ----------------------------------------------------------------------------
// BlueZ pairing agent (org.bluez.Agent1)
// Capability "DisplayYesNo" -> BlueZ drives numeric-comparison pairing: it calls
// RequestConfirmation(device, passkey) on both sides with the same 6-digit code.
// We answer with a *delayed* D-Bus reply so the user can compare/confirm first.
// ----------------------------------------------------------------------------
class BluezAgent : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.Agent1")
public:
    explicit BluezAgent(BluetoothController *controller)
        : QDBusAbstractAdaptor(controller), m_controller(controller) {}

public slots:
    void Release() {}

    // Legacy / non-SSP flows -- accept sensibly so pairing still works.
    QString RequestPinCode(const QDBusObjectPath &) { return QStringLiteral("0000"); }
    void DisplayPinCode(const QDBusObjectPath &, const QString &) {}
    quint32 RequestPasskey(const QDBusObjectPath &) { return 0; }
    void DisplayPasskey(const QDBusObjectPath &, quint32, quint16) {}

    // The numeric-comparison request -- drives the confirmation popup. The call
    // context lives on the registered object (the controller), so it captures
    // the delayed reply itself; the adaptor only forwards.
    void RequestConfirmation(const QDBusObjectPath &device, quint32 passkey) {
        m_controller->beginPairingConfirm(device.path(), passkey);
    }

    // "Just works" / authorization requests -- accept (adapter is pairable).
    void RequestAuthorization(const QDBusObjectPath &) {}
    void AuthorizeService(const QDBusObjectPath &, const QString &) {}

    void Cancel() {
        m_controller->cancelPairing();
    }

private:
    BluetoothController *m_controller;
};

// ============================================================================
// 3. QNX BACKEND (PPS - Persistent Publish/Subscribe)
// ============================================================================
#elif defined(Q_OS_QNX)
#include <QFileSystemWatcher>
#include <QTextStream>

class QnxPpsBackend : public IBluetoothBackend {
    Q_OBJECT
public:
    QnxPpsBackend(BluetoothController *controller) : IBluetoothBackend(controller) {
        // Setup a watcher to monitor the QNX PPS status object
        m_watcher = new QFileSystemWatcher(this);
        m_statusPpsPath = "/pps/services/bluetooth/remote_device/status";

        if (QFile::exists(m_statusPpsPath)) {
            m_watcher->addPath(m_statusPpsPath);
            connect(m_watcher, &QFileSystemWatcher::fileChanged, this, &QnxPpsBackend::readPpsStatus);
            readPpsStatus(m_statusPpsPath); // Initial read
            m_controller->setConnectedStatus(true);
        } else {
            qWarning() << "QNX PPS path not found:" << m_statusPpsPath;
        }
    }

    void play() override { writeCmd("msg::play\n"); }
    void pause() override { writeCmd("msg::pause\n"); }
    void next() override { writeCmd("msg::next\n"); }
    void previous() override { writeCmd("msg::previous\n"); }
    void fastForward() override { writeCmd("msg::fastforward\n"); }
    void rewind() override { writeCmd("msg::rewind\n"); }
    void setVolume(int vol) override { writeCmd(QString("msg::volume_set\nvol::%1\n").arg(vol)); }

private slots:
    void readPpsStatus(const QString &path) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

        QTextStream in(&file);
        QString title, artist, album, status;
        uint duration = 0;

        while (!in.atEnd()) {
            QString line = in.readLine();
            if (line.startsWith("title::")) title = line.mid(7);
            else if (line.startsWith("artist::")) artist = line.mid(8);
            else if (line.startsWith("album::")) album = line.mid(7);
            else if (line.startsWith("duration::")) duration = line.mid(10).toUInt();
            else if (line.startsWith("status::")) status = line.mid(8);
            // Parse other keys as needed for your specific QNX stack
        }

        if (!title.isEmpty()) m_controller->setTrackData(title, artist, album, duration);
        if (!status.isEmpty()) m_controller->setPlaybackStatus(status);
    }

private:
    void writeCmd(const QString &cmdPayload) {
        QFile controlPps("/pps/services/bluetooth/remote_device/control");
        if (controlPps.open(QIODevice::WriteOnly | QIODevice::Append)) {
            controlPps.write(cmdPayload.toUtf8());
            controlPps.close();
        }
    }

    QFileSystemWatcher *m_watcher;
    QString m_statusPpsPath;
};

// ============================================================================
// 4. MOCK BACKEND (Fallback for Windows/Mac testing)
// ============================================================================
#else
class MockBackend : public IBluetoothBackend {
public:
    MockBackend(BluetoothController *controller) : IBluetoothBackend(controller) {}
    void play() override { m_controller->setPlaybackStatus("playing"); }
    void pause() override { m_controller->setPlaybackStatus("paused"); }
    void next() override {}
    void previous() override {}
    void fastForward() override {}
    void rewind() override {}
    void setVolume(int vol) override { m_controller->setVolumeInternal(vol); }
};
#endif


// ============================================================================
// PLATFORM AGNOSTIC CONTROLLER IMPLEMENTATION
// ============================================================================

// ============================================================================
// Paired-devices model
// ============================================================================
int BluetoothDevicesModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_devices.size();
}

QVariant BluetoothDevicesModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_devices.size()) return QVariant();
    const BtDevice &d = m_devices.at(index.row());
    switch (role) {
    case NameRole:      return d.name;
    case AddressRole:   return d.address;
    case ConnectedRole: return d.connected;
    case PathRole:      return d.path;
    default:            return QVariant();
    }
}

QHash<int, QByteArray> BluetoothDevicesModel::roleNames() const
{
    return {
        { NameRole, "name" },
        { AddressRole, "address" },
        { ConnectedRole, "connected" },
        { PathRole, "path" }
    };
}

void BluetoothDevicesModel::setDevices(const QVector<BtDevice> &devices)
{
    beginResetModel();
    m_devices = devices;
    endResetModel();
}

BluetoothController::BluetoothController(QObject *parent) : QObject(parent)
{
    m_nam = new QNetworkAccessManager(this);
    m_devicesModel = new BluetoothDevicesModel(this);
    // Keep the paired list fresh as devices connect/disconnect.
    connect(this, &BluetoothController::connectedChanged, this, &BluetoothController::refreshPairedDevices);
    connect(this, &BluetoothController::enabledChanged, this, &BluetoothController::refreshPairedDevices);

    // Initialize the correct backend based on OS
#if defined(Q_OS_LINUX)
    m_backend = new LinuxBluezBackend(this);
    setupAgent();
#elif defined(Q_OS_QNX)
    m_backend = new QnxPpsBackend(this);
#else
    m_backend = new MockBackend(this);
#endif

    refreshEnabled();
    refreshPairedDevices();
}

BluetoothController::~BluetoothController() {
    // m_backend is parented to this class, memory is managed.
}

// OS-specific Backends call these setters to update QML securely
void BluetoothController::setTrackData(const QString &title, const QString &artist, const QString &album, uint duration) {
    bool changed = false;
    if (m_trackTitle != title || m_artist != artist || m_album != album) {
        m_trackTitle = title;
        m_artist = artist;
        m_album = album;
        changed = true;
        emit metadataChanged();
    }
    if (m_duration != duration) {
        m_duration = duration;
        emit durationChanged();
    }

    // Fetch new cover art via internet if the track string changed
    if (changed && !m_trackTitle.isEmpty()) {
        fetchCoverArt(m_trackTitle, m_artist);
    }
}

void BluetoothController::setPlaybackStatus(const QString &status) {
    if (m_playbackStatus != status) {
        m_playbackStatus = status;
        emit statusChanged();
    }
}

void BluetoothController::setPositionInternal(uint pos) {
    if (m_position != pos) {
        m_position = pos;
        emit positionChanged();
    }
}

void BluetoothController::setVolumeInternal(int vol) {
    int safeVol = qBound(0, vol, 100);
    if (m_volume != safeVol) {
        m_volume = safeVol;
        emit volumeChanged();
    }
}

void BluetoothController::setConnectedStatus(bool connected) {
    if (m_connected != connected) {
        m_connected = connected;
        emit connectedChanged();
    }
}

// QML Invokables (Delegated to Backend)
void BluetoothController::play() { m_backend->play(); }
void BluetoothController::pause() { m_backend->pause(); }
void BluetoothController::next() { m_backend->next(); }
void BluetoothController::previous() { m_backend->previous(); }
void BluetoothController::fastForward() { m_backend->fastForward(); }
void BluetoothController::rewind() { m_backend->rewind(); }
void BluetoothController::setVolume(int vol) { m_backend->setVolume(qBound(0, vol, 100)); }

void BluetoothController::setEnabled(bool enabled) {
    // Re-sync with the real adapter first: the cached m_enabled can go stale
    // (it defaults to true), which previously made a toggle silently no-op --
    // the "sometimes can't turn Bluetooth on" bug. Always attempt the change.
    updateAdapterPowered();
    if (m_enabled == enabled) return;

    if (!setAdapterPowered(enabled)) {
        updateAdapterPowered();
    }
}

void BluetoothController::refreshEnabled() {
    updateAdapterPowered();
}

// ============================================================================
// Pairing agent
// ============================================================================
void BluetoothController::setupAgent()
{
#if defined(Q_OS_LINUX)
    if (!QDBusConnection::systemBus().isConnected()) return;

    m_agent = new BluezAgent(this); // adaptor parented to this controller

    const QString agentPath = QStringLiteral("/sylph/agent");
    if (!QDBusConnection::systemBus().registerObject(agentPath, this, QDBusConnection::ExportAdaptors)) {
        qWarning() << "Bluetooth: failed to register pairing agent object";
        return;
    }

    QDBusInterface mgr("org.bluez", "/org/bluez", "org.bluez.AgentManager1", QDBusConnection::systemBus());
    mgr.call("RegisterAgent", QVariant::fromValue(QDBusObjectPath(agentPath)), QStringLiteral("DisplayYesNo"));
    mgr.call("RequestDefaultAgent", QVariant::fromValue(QDBusObjectPath(agentPath)));

    // Make the car pairable + discoverable so phones can find it.
    applyAdapterDefaults();
#endif
}

void BluetoothController::applyAdapterDefaults()
{
#if defined(Q_OS_LINUX)
    const QString adapterPath = resolveAdapterPath();
    if (adapterPath.isEmpty()) return;

    // DiscoverableTimeout = 0 keeps the adapter discoverable indefinitely.
    QDBusInterface props("org.bluez", adapterPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    props.call("Set", "org.bluez.Adapter1", "Pairable",
               QVariant::fromValue(QDBusVariant(QVariant::fromValue(true))));
    props.call("Set", "org.bluez.Adapter1", "DiscoverableTimeout",
               QVariant::fromValue(QDBusVariant(QVariant::fromValue(quint32(0)))));
    props.call("Set", "org.bluez.Adapter1", "Discoverable",
               QVariant::fromValue(QDBusVariant(QVariant::fromValue(true))));

    updateAdapterInfo();
#endif
}

void BluetoothController::attemptPowerOn(int attempt)
{
#if defined(Q_OS_LINUX)
    const QString adapterPath = resolveAdapterPath();
    if (adapterPath.isEmpty()) return;

    QDBusInterface props("org.bluez", adapterPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    props.call("Set", "org.bluez.Adapter1", "Powered",
               QVariant::fromValue(QDBusVariant(QVariant::fromValue(true))));

    updateAdapterPowered(); // re-reads Powered, emits enabledChanged on success
    if (m_enabled) {
        // BlueZ resets pairable/discoverable across a power cycle -- re-assert.
        applyAdapterDefaults();
        return;
    }

    if (attempt >= 9) return; // give up after ~2s of retries
    QTimer::singleShot(200, this, [this, attempt]() { attemptPowerOn(attempt + 1); });
#else
    Q_UNUSED(attempt);
#endif
}

void BluetoothController::setDeviceName(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) return;
#if defined(Q_OS_LINUX)
    const QString adapterPath = resolveAdapterPath();
    if (adapterPath.isEmpty()) return;
    QDBusInterface props("org.bluez", adapterPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    props.call("Set", "org.bluez.Adapter1", "Alias",
               QVariant::fromValue(QDBusVariant(QVariant::fromValue(trimmed))));
    updateAdapterInfo();
#else
    if (m_deviceName != trimmed) { m_deviceName = trimmed; emit deviceNameChanged(); }
#endif
}

void BluetoothController::setDiscoverable(bool discoverable)
{
#if defined(Q_OS_LINUX)
    const QString adapterPath = resolveAdapterPath();
    if (adapterPath.isEmpty()) return;
    QDBusInterface props("org.bluez", adapterPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    props.call("Set", "org.bluez.Adapter1", "DiscoverableTimeout",
               QVariant::fromValue(QDBusVariant(QVariant::fromValue(quint32(0)))));
    props.call("Set", "org.bluez.Adapter1", "Discoverable",
               QVariant::fromValue(QDBusVariant(QVariant::fromValue(discoverable))));
    updateAdapterInfo();
#else
    if (m_discoverable != discoverable) { m_discoverable = discoverable; emit discoverableChanged(); }
#endif
}

void BluetoothController::updateAdapterInfo()
{
#if defined(Q_OS_LINUX)
    const QString adapterPath = resolveAdapterPath();
    if (adapterPath.isEmpty()) return;
    QDBusInterface props("org.bluez", adapterPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());

    QDBusReply<QVariant> alias = props.call("Get", "org.bluez.Adapter1", "Alias");
    if (alias.isValid()) {
        const QString name = alias.value().toString();
        if (m_deviceName != name) { m_deviceName = name; emit deviceNameChanged(); }
    }

    QDBusReply<QVariant> disc = props.call("Get", "org.bluez.Adapter1", "Discoverable");
    if (disc.isValid()) {
        const bool d = disc.value().toBool();
        if (m_discoverable != d) { m_discoverable = d; emit discoverableChanged(); }
    }
#endif
}

void BluetoothController::beginPairingConfirm(const QString &devicePath, quint32 passkey)
{
#if defined(Q_OS_LINUX)
    // Called synchronously from the agent's slot, i.e. during the D-Bus
    // dispatch -- so QDBusContext (on this registered object) is valid here.
    setDelayedReply(true);
    m_pendingMsg = message();
    m_pendingConn = connection();
    m_hasPendingPair = true;

    const QString code = QString("%1").arg(passkey, 6, 10, QChar('0'));
    // Defer the (blocking) name lookup + UI signal until after the dispatch
    // returns -- never make a nested blocking D-Bus call from inside it. Guard
    // against a Cancel() that may already have arrived (e.g. a re-pair of an
    // already-bonded device), so we don't pop a dialog for a dead request.
    QMetaObject::invokeMethod(this, [this, devicePath, code]() {
        if (!m_hasPendingPair) return;
        emit pairingRequested(deviceAlias(devicePath), code);
    }, Qt::QueuedConnection);
#else
    Q_UNUSED(devicePath);
    Q_UNUSED(passkey);
#endif
}

void BluetoothController::confirmPairing(bool accept)
{
#if defined(Q_OS_LINUX)
    if (!m_hasPendingPair) return;
    m_hasPendingPair = false;
    if (accept)
        m_pendingConn.send(m_pendingMsg.createReply());
    else
        m_pendingConn.send(m_pendingMsg.createErrorReply(
            "org.bluez.Error.Rejected", "Pairing rejected by user"));
#else
    Q_UNUSED(accept);
#endif
}

void BluetoothController::cancelPairing()
{
#if defined(Q_OS_LINUX)
    m_hasPendingPair = false;
#endif
    emit pairingCancelled();
}

QString BluetoothController::deviceAlias(const QString &devicePath) const
{
#if defined(Q_OS_LINUX)
    QDBusInterface props("org.bluez", devicePath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    QDBusReply<QVariant> alias = props.call("Get", "org.bluez.Device1", "Alias");
    if (alias.isValid() && !alias.value().toString().isEmpty())
        return alias.value().toString();
    QDBusReply<QVariant> name = props.call("Get", "org.bluez.Device1", "Name");
    if (name.isValid() && !name.value().toString().isEmpty())
        return name.value().toString();
#endif
    Q_UNUSED(devicePath);
    return QStringLiteral("a new device");
}

// ============================================================================
// Paired devices (the car lists bonded devices; it never scans)
// ============================================================================
void BluetoothController::refreshPairedDevices()
{
#if defined(Q_OS_LINUX)
    QVector<BtDevice> devices;
    const QString adapterPath = resolveAdapterPath();
    if (!adapterPath.isEmpty()) {
        // Introspect the adapter to find its device children (dev_XX_...).
        QDBusMessage introMsg = QDBusMessage::createMethodCall(
            "org.bluez", adapterPath, "org.freedesktop.DBus.Introspectable", "Introspect");
        QDBusMessage introReply = QDBusConnection::systemBus().call(introMsg);
        if (introReply.type() == QDBusMessage::ReplyMessage && !introReply.arguments().isEmpty()) {
            const QString xml = introReply.arguments().at(0).toString();
            int pos = 0;
            while ((pos = xml.indexOf("<node name=\"", pos)) != -1) {
                pos += 12;
                int end = xml.indexOf('"', pos);
                if (end == -1) break;
                const QString child = xml.mid(pos, end - pos);
                pos = end;
                if (!child.startsWith("dev_")) continue;

                const QString devPath = adapterPath + "/" + child;
                QDBusInterface props("org.bluez", devPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
                QDBusReply<QVariant> paired = props.call("Get", "org.bluez.Device1", "Paired");
                if (!paired.isValid() || !paired.value().toBool()) continue; // bonded only

                BtDevice dev;
                dev.path = devPath;
                QDBusReply<QVariant> addr = props.call("Get", "org.bluez.Device1", "Address");
                if (addr.isValid()) dev.address = addr.value().toString();
                QDBusReply<QVariant> alias = props.call("Get", "org.bluez.Device1", "Alias");
                dev.name = alias.isValid() ? alias.value().toString() : QString();
                if (dev.name.isEmpty()) {
                    QDBusReply<QVariant> name = props.call("Get", "org.bluez.Device1", "Name");
                    if (name.isValid()) dev.name = name.value().toString();
                }
                if (dev.name.isEmpty()) dev.name = dev.address;
                QDBusReply<QVariant> conn = props.call("Get", "org.bluez.Device1", "Connected");
                dev.connected = conn.isValid() && conn.value().toBool();
                devices.append(dev);
            }
        }
    }
    m_devicesModel->setDevices(devices);
#endif
}

void BluetoothController::connectDevice(const QString &path)
{
#if defined(Q_OS_LINUX)
    if (path.isEmpty()) return;
    QDBusMessage msg = QDBusMessage::createMethodCall("org.bluez", path, "org.bluez.Device1", "Connect");
    QDBusConnection::systemBus().asyncCall(msg); // can take seconds -- don't block
    QTimer::singleShot(2000, this, &BluetoothController::refreshPairedDevices);
#else
    Q_UNUSED(path);
#endif
}

void BluetoothController::disconnectDevice(const QString &path)
{
#if defined(Q_OS_LINUX)
    if (path.isEmpty()) return;
    QDBusMessage msg = QDBusMessage::createMethodCall("org.bluez", path, "org.bluez.Device1", "Disconnect");
    QDBusConnection::systemBus().asyncCall(msg);
    QTimer::singleShot(1000, this, &BluetoothController::refreshPairedDevices);
#else
    Q_UNUSED(path);
#endif
}

void BluetoothController::forgetDevice(const QString &path)
{
#if defined(Q_OS_LINUX)
    if (path.isEmpty()) return;
    const QString adapterPath = resolveAdapterPath();
    if (adapterPath.isEmpty()) return;
    QDBusMessage msg = QDBusMessage::createMethodCall("org.bluez", adapterPath, "org.bluez.Adapter1", "RemoveDevice");
    msg << QVariant::fromValue(QDBusObjectPath(path));
    QDBusConnection::systemBus().asyncCall(msg);
    QTimer::singleShot(500, this, &BluetoothController::refreshPairedDevices);
#else
    Q_UNUSED(path);
#endif
}

void BluetoothController::updatePosition(uint ms) {
    if (m_playbackStatus == "playing") {
        m_position += ms;
        if (m_duration > 0 && m_position > m_duration) m_position = m_duration;
        emit positionChanged();
    }
}

bool BluetoothController::updateAdapterPowered()
{
#if defined(Q_OS_LINUX)
    const QString adapterPath = resolveAdapterPath();
    if (adapterPath.isEmpty()) return false;

    QDBusInterface props("org.bluez", adapterPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    QDBusReply<QVariant> reply = props.call("Get", "org.bluez.Adapter1", "Powered");
    if (!reply.isValid()) return false;

    const bool enabled = reply.value().toBool();
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit enabledChanged();
    }
    updateAdapterInfo();
    return true;
#else
    return false;
#endif
}

bool BluetoothController::setAdapterPowered(bool enabled)
{
#if defined(Q_OS_LINUX)
    const QString adapterPath = resolveAdapterPath();
    if (adapterPath.isEmpty()) return false;

    if (enabled) {
        // The adapter is frequently rfkill soft-blocked; BlueZ refuses
        // Powered=true until it's unblocked AND has had a moment to register
        // the change. Unblock, then attempt the power-on with short async
        // retries so the GUI thread never blocks.
        // rfkill commonly lives in /usr/sbin, which may not be on a GUI app's
        // PATH -- resolve it explicitly.
        QString rfkill = QStandardPaths::findExecutable("rfkill");
        if (rfkill.isEmpty()) {
            for (const QString &cand : {"/usr/sbin/rfkill", "/sbin/rfkill", "/usr/bin/rfkill"}) {
                if (QFile::exists(cand)) { rfkill = cand; break; }
            }
        }
        if (!rfkill.isEmpty())
            QProcess::startDetached(rfkill, {"unblock", "bluetooth"});

        attemptPowerOn(0);
        return true; // final state reported asynchronously via updateAdapterPowered()
    }

    QDBusInterface props("org.bluez", adapterPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    QDBusReply<void> reply = props.call("Set", "org.bluez.Adapter1", "Powered",
                                       QVariant::fromValue(QDBusVariant(QVariant::fromValue(false))));
    if (!reply.isValid()) return false;

    updateAdapterPowered();
    return true;
#else
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit enabledChanged();
    }
    return true;
#endif
}

QString BluetoothController::resolveAdapterPath()
{
#if defined(Q_OS_LINUX)
    if (!m_adapterPath.isEmpty()) return m_adapterPath;

    const QStringList candidates = {
        "/org/bluez/hci0",
        "/org/bluez/hci1",
        "/org/bluez/hci2"
    };

    for (const QString &path : candidates) {
        QDBusInterface props("org.bluez", path, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
        QDBusReply<QVariant> reply = props.call("Get", "org.bluez.Adapter1", "Powered");
        if (reply.isValid()) {
            m_adapterPath = path;
            break;
        }
    }

    return m_adapterPath;
#else
    return QString();
#endif
}

// ============================================================================
// iTunes Cover Art Fetching Logic (Platform Agnostic)
// ============================================================================

QString BluetoothController::coverCacheKey(const QString &title, const QString &artist) const {
    QString key = title.trimmed();
    QString artistTrimmed = artist.trimmed();
    if (!artistTrimmed.isEmpty()) {
        key += "|" + artistTrimmed;
    }
    return key;
}

QString BluetoothController::coverCacheFilePath(const QString &key) const {
    QString hash = QString(QCryptographicHash::hash(key.toUtf8(), QCryptographicHash::Md5).toHex());
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers";
    QDir().mkpath(cacheDir);
    return cacheDir + "/" + hash + ".jpg";
}

void BluetoothController::setCoverArtPlaceholder() {
    if (m_coverArt != "qrc:/cover_placeholder.png") {
        m_coverArt = "qrc:/cover_placeholder.png";
        emit coverArtChanged();
    }
}

void BluetoothController::fetchCoverArt(const QString &title, const QString &artist) {
    if (title.isEmpty() || title == "No Track") {
        setCoverArtPlaceholder();
        return;
    }

    QString key = coverCacheKey(title, artist);
    if (key.isEmpty() || key == m_lastFetchedKey) return;

    m_lastFetchedKey = key;
    m_pendingCoverKey = key;

    // 1. Generate the cache filename
    QString filePath = coverCacheFilePath(key);

    // 2. CACHE HIT: Does the file already exist?
    if (QFile::exists(filePath)) {
        // "Touch" the file to update its modified time to RIGHT NOW.
        // This ensures the LRU cache knows it was recently used and won't delete it.
        QFile file(filePath);
        file.setFileTime(QDateTime::currentDateTime(), QFileDevice::FileModificationTime);

        m_coverArt = "file://" + filePath;
        emit coverArtChanged();
        return; // Exit early! No network request needed.
    }

    // 3. CACHE MISS: Fetch from the internet
    QString query = QString("%1 %2").arg(title, artist);
    query = QUrl::toPercentEncoding(query);
    QString url = QString("https://itunes.apple.com/search?term=%1&entity=song&limit=1").arg(query);

    QNetworkRequest request((QUrl(url)));
    QNetworkReply *reply = m_nam->get(request);
    reply->setProperty("coverKey", key);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { onCoverArtSearchFinished(reply); });
}

void BluetoothController::onCoverArtSearchFinished(QNetworkReply *reply) {
    QString key = reply->property("coverKey").toString();
    reply->deleteLater();
    if (key.isEmpty() || key != m_pendingCoverKey) return;
    if (reply->error() != QNetworkReply::NoError) {
        setCoverArtPlaceholder();
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonArray results = doc.object().value("results").toArray();

    if (results.isEmpty()) {
        setCoverArtPlaceholder();
        return;
    }

    QString artworkUrl = results.first().toObject().value("artworkUrl100").toString();
    artworkUrl.replace("100x100", "600x600"); // Request higher resolution

    QNetworkRequest imgRequest((QUrl(artworkUrl)));
    QNetworkReply *imgReply = m_nam->get(imgRequest);
    imgReply->setProperty("coverKey", key);
    connect(imgReply, &QNetworkReply::finished, this, [this, imgReply]() { onCoverArtDownloaded(imgReply); });
}

void BluetoothController::onCoverArtDownloaded(QNetworkReply *reply) {
    QString key = reply->property("coverKey").toString();
    reply->deleteLater();
    if (key.isEmpty() || key != m_pendingCoverKey) return;
    if (reply->error() != QNetworkReply::NoError) {
        setCoverArtPlaceholder();
        return;
    }

    QString filePath = coverCacheFilePath(key);

    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(reply->readAll());
        file.close();

        m_coverArt = "file://" + filePath;
        emit coverArtChanged();

        // Trigger the cache check
        manageCacheSize();
    }
}

void BluetoothController::manageCacheSize() {
    QString cacheDirPath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers";
    QDir cacheDir(cacheDirPath);

    if (!cacheDir.exists()) return;

    QFileInfoList files = cacheDir.entryInfoList(QDir::Files | QDir::NoDotAndDotDot);
    qint64 totalSize = 0;

    // 1. Calculate the current total size of all cover art
    for (const QFileInfo &fileInfo : files) {
        totalSize += fileInfo.size();
    }

    // 1 GB in bytes
    constexpr qint64 kMaxCacheSize = 1073741824LL;

    // If we are under the limit, do nothing
    if (totalSize <= kMaxCacheSize) return;

    qDebug() << "Cache limit reached! Cleaning up oldest covers...";

    // 2. Sort files by Last Modified Time (Oldest first)
    std::sort(files.begin(), files.end(), [](const QFileInfo &a, const QFileInfo &b) {
        return a.lastModified() < b.lastModified();
    });

    // 3. Delete oldest files until we are down to 900 MB
    // (We drop slightly below the max limit so we aren't running this cleanup on every single new song)
    constexpr qint64 kTargetSize = kMaxCacheSize - (100 * 1024 * 1024); // ~900 MB

    for (const QFileInfo &fileInfo : files) {
        if (totalSize <= kTargetSize) break;

        QFile file(fileInfo.absoluteFilePath());
        qint64 fileSize = fileInfo.size();

        if (file.remove()) {
            totalSize -= fileSize;
            qDebug() << "Evicted from cache:" << fileInfo.fileName();
        }
    }
}

#include "BluetoothController.moc"
