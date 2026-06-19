#include "WifiController.h"

#include <QProcess>
#include <QStandardPaths>

WifiNetworksModel::WifiNetworksModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int WifiNetworksModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_networks.size();
}

QVariant WifiNetworksModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_networks.size()) return QVariant();

    const WifiNetwork &network = m_networks.at(index.row());
    switch (role) {
    case SsidRole:
        return network.ssid;
    case SignalRole:
        return network.signal;
    case SecurityRole:
        return network.security;
    case InUseRole:
        return network.inUse;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> WifiNetworksModel::roleNames() const
{
    return {
        { SsidRole, "ssid" },
        { SignalRole, "signal" },
        { SecurityRole, "security" },
        { InUseRole, "inUse" }
    };
}

void WifiNetworksModel::setNetworks(const QVector<WifiNetwork> &networks)
{
    beginResetModel();
    m_networks = networks;
    endResetModel();
}

const WifiNetwork *WifiNetworksModel::networkAt(int index) const
{
    if (index < 0 || index >= m_networks.size()) return nullptr;
    return &m_networks.at(index);
}

void WifiNetworksModel::clear()
{
    beginResetModel();
    m_networks.clear();
    endResetModel();
}

WifiController::WifiController(QObject *parent)
    : QObject(parent)
    , m_model(new WifiNetworksModel(this))
{
    updateAvailable();
    updateRadioState();
    if (m_available && m_enabled) {
        refresh();
    }
}

void WifiController::refresh()
{
    updateAvailable();
    updateRadioState();

    if (!m_available) {
        m_model->clear();
        setConnectedSsid("");
        setLastError("Wi-Fi control unavailable (nmcli not found).");
        return;
    }

    if (!m_enabled) {
        m_model->clear();
        setConnectedSsid("");
        setLastError("Wi-Fi is disabled.");
        return;
    }

    if (m_scanning) return;   // a scan is already in flight

    // Run the rescan ASYNCHRONOUSLY. nmcli's "--rescan yes" can take several
    // seconds; doing it with a blocking waitForFinished() froze the GUI thread
    // (the "turning Wi-Fi on hangs the app" bug). Stream the result via signals.
    setScanning(true);
    setLastError("");

    QProcess *proc = new QProcess(this);

    connect(proc, &QProcess::finished, this,
            [this, proc](int exitCode, QProcess::ExitStatus status) {
        proc->disconnect();
        setScanning(false);
        if (status != QProcess::NormalExit || exitCode != 0) {
            setLastError("Failed to scan for Wi-Fi networks.");
        } else {
            handleScanOutput(QString::fromUtf8(proc->readAllStandardOutput()));
        }
        proc->deleteLater();
    });

    connect(proc, &QProcess::errorOccurred, this,
            [this, proc](QProcess::ProcessError) {
        proc->disconnect();
        setScanning(false);
        setLastError("Failed to scan for Wi-Fi networks.");
        proc->deleteLater();
    });

    proc->start("nmcli", {"-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"});
}

void WifiController::connectToNetwork(const QString &ssid, const QString &password)
{
    updateAvailable();

    if (!m_available) {
        setLastError("Wi-Fi control unavailable (nmcli not found).");
        return;
    }

    const QString trimmed = ssid.trimmed();
    if (trimmed.isEmpty()) {
        setLastError("Select a Wi-Fi network.");
        return;
    }

    QStringList args = {"dev", "wifi", "connect", trimmed};
    if (!password.trimmed().isEmpty()) {
        args << "password" << password.trimmed();
    }

    bool ok = false;
    runNmcli(args, 15000, &ok);
    if (!ok) {
        setLastError("Failed to connect to the selected network.");
        return;
    }

    setLastError("");
    refresh();
}

void WifiController::disconnect()
{
    updateAvailable();

    if (!m_available) {
        setLastError("Wi-Fi control unavailable (nmcli not found).");
        return;
    }

    const QString device = findWifiDevice();
    if (device.isEmpty()) {
        setLastError("No Wi-Fi device found.");
        return;
    }

    bool ok = false;
    runNmcli({"dev", "disconnect", device}, 8000, &ok);
    if (!ok) {
        setLastError("Failed to disconnect Wi-Fi.");
        return;
    }

    setLastError("");
    refresh();
}

void WifiController::setEnabled(bool enabled)
{
    updateAvailable();

    if (!m_available) {
        setLastError("Wi-Fi control unavailable (nmcli not found).");
        return;
    }

    if (m_enabled == enabled) return;

    bool ok = false;
    runNmcli({"radio", "wifi", enabled ? "on" : "off"}, 8000, &ok);
    if (!ok) {
        setLastError("Failed to toggle Wi-Fi.");
        updateRadioState();
        return;
    }

    setLastError("");
    updateRadioState();

    if (m_enabled) {
        refresh();
    } else {
        m_model->clear();
        setConnectedSsid("");
    }
}

void WifiController::setScanning(bool scanning)
{
    if (m_scanning == scanning) return;
    m_scanning = scanning;
    emit scanningChanged();
}

void WifiController::setLastError(const QString &error)
{
    if (m_lastError == error) return;
    m_lastError = error;
    emit lastErrorChanged();
}

void WifiController::setConnectedSsid(const QString &ssid)
{
    if (m_connectedSsid == ssid) return;
    m_connectedSsid = ssid;
    emit connectedSsidChanged();
}

void WifiController::updateRadioState()
{
    if (!m_available) return;

    bool ok = false;
    const QString output = runNmcli({"-t", "-f", "WIFI", "g"}, 4000, &ok);
    if (!ok) return;

    const QString value = output.split('\n', Qt::SkipEmptyParts).value(0).trimmed();
    const bool enabled = (value == "enabled");
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit enabledChanged();
    }
}

void WifiController::updateAvailable()
{
    const bool available = !QStandardPaths::findExecutable("nmcli").isEmpty();
    if (m_available == available) return;
    m_available = available;
    emit availableChanged();

    if (!m_available) {
        if (m_enabled) {
            m_enabled = false;
            emit enabledChanged();
        }
        m_model->clear();
        setConnectedSsid("");
    }
}

void WifiController::handleScanOutput(const QString &output)
{
    QVector<WifiNetwork> networks;
    QString connected;

    const QStringList lines = output.split('\n', Qt::SkipEmptyParts);
    networks.reserve(lines.size());

    for (const QString &line : lines) {
        const QStringList parts = splitTerseLine(line);
        if (parts.size() < 4) continue;

        WifiNetwork network;
        network.inUse = parts.at(0).trimmed() == "*";
        network.ssid = parts.at(1).trimmed();
        network.signal = parts.at(2).trimmed().toInt();
        network.security = parts.at(3).trimmed();

        if (network.ssid.isEmpty() || network.ssid == "--") continue; // skip empty/hidden

        if (network.inUse) connected = network.ssid;
        
        bool found = false;
        for (int i = 0; i < networks.size(); ++i) {
            if (networks[i].ssid == network.ssid) {
                if (network.inUse) networks[i].inUse = true;
                if (network.signal > networks[i].signal) networks[i].signal = network.signal;
                found = true;
                break;
            }
        }
        
        if (!found) {
            networks.append(network);
        }
    }

    m_model->setNetworks(networks);
    setConnectedSsid(connected);
}

QString WifiController::runNmcli(const QStringList &args, int timeoutMs, bool *ok) const
{
    if (ok) *ok = false;

    QProcess proc;
    proc.start("nmcli", args);
    if (!proc.waitForStarted(timeoutMs)) {
        return QString();
    }
    if (!proc.waitForFinished(timeoutMs)) {
        proc.kill();
        proc.waitForFinished();
        return QString();
    }

    if (ok) {
        *ok = (proc.exitStatus() == QProcess::NormalExit && proc.exitCode() == 0);
    }

    return QString::fromUtf8(proc.readAllStandardOutput());
}

QString WifiController::findWifiDevice() const
{
    bool ok = false;
    const QString output = runNmcli({"-t", "-f", "DEVICE,TYPE,STATE", "dev"}, 4000, &ok);
    if (!ok) return QString();

    QString fallback;
    const QStringList lines = output.split('\n', Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QStringList parts = splitTerseLine(line);
        if (parts.size() < 3) continue;

        const QString device = parts.at(0).trimmed();
        const QString type = parts.at(1).trimmed();
        const QString state = parts.at(2).trimmed();
        if (type != "wifi" || device.isEmpty()) continue;

        if (state == "connected" || state == "connecting") {
            return device;
        }
        if (fallback.isEmpty()) fallback = device;
    }

    return fallback;
}

QStringList WifiController::splitTerseLine(const QString &line)
{
    QStringList parts;
    QString current;
    bool escape = false;

    for (const QChar ch : line) {
        if (escape) {
            current.append(ch);
            escape = false;
            continue;
        }
        if (ch == '\\') {
            escape = true;
            continue;
        }
        if (ch == ':') {
            parts.append(current);
            current.clear();
            continue;
        }
        current.append(ch);
    }

    parts.append(current);
    return parts;
}
