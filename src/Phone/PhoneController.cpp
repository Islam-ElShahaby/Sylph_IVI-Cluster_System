#include "PhoneController.h"
#include <QDebug>
#include <QDateTime>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QStandardPaths>
#include <QApplication>

// LINUX BACKEND
#include <QtDBus/QDBusInterface>
#include <QtDBus/QDBusReply>
#include <QtDBus/QDBusMessage>
#include <QtDBus/QDBusArgument>
#include <QtDBus/QDBusVariant>
#include <QTimer>
#include <QProcess>
#include <functional>
#include <QMediaPlayer>
#include <QAudioOutput>

// ============================================================================
// Contacts Model
// ============================================================================
ContactsModel::ContactsModel(QObject *parent) : QAbstractListModel(parent) {}

int ContactsModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_contacts.count();
}

QVariant ContactsModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_contacts.count())
        return QVariant();

    const auto &contact = m_contacts[index.row()];
    if (role == NameRole) return contact.name;
    if (role == NumbersRole) return QVariant(contact.numbers);
    return QVariant();
}

QHash<int, QByteArray> ContactsModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[NumbersRole] = "numbers";
    return roles;
}

void ContactsModel::setContacts(const QList<Contact> &contacts) {
    beginResetModel();
    m_contacts = contacts;
    endResetModel();
}

void ContactsModel::clear() {
    beginResetModel();
    m_contacts.clear();
    endResetModel();
}

// ============================================================================
// Recents Model
// ============================================================================
RecentsModel::RecentsModel(QObject *parent) : QAbstractListModel(parent) {}

int RecentsModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_recents.count();
}

QVariant RecentsModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_recents.count())
        return QVariant();

    const auto &recent = m_recents[index.row()];
    if (role == NameRole) return recent.name;
    if (role == NumberRole) return recent.number;
    if (role == TypeRole) return recent.type;
    if (role == TimeRole) return recent.time;
    return QVariant();
}

QHash<int, QByteArray> RecentsModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[NumberRole] = "number";
    roles[TypeRole] = "type";
    roles[TimeRole] = "time";
    return roles;
}

void RecentsModel::setRecents(const QList<RecentCall> &recents) {
    beginResetModel();
    m_recents = recents;
    endResetModel();
}

void RecentsModel::clear() {
    beginResetModel();
    m_recents.clear();
    endResetModel();
}

// ============================================================================
// ABSTRACT BACKEND
// ============================================================================
class IPhoneBackend : public QObject {
public:
    IPhoneBackend(PhoneController *controller) : QObject(controller), m_controller(controller) {}
    virtual ~IPhoneBackend() = default;
    virtual void dial(const QString &number) = 0;
    virtual void hangup() = 0;
    virtual void answer() = 0;
protected:
    PhoneController *m_controller;
};

// ============================================================================
// vCard Parser Helpers
// ============================================================================
static QList<ContactsModel::Contact> parseVCardContacts(const QString &vcfContent)
{
    QList<ContactsModel::Contact> contacts;
    const QStringList cards = vcfContent.split("END:VCARD", Qt::SkipEmptyParts);

    for (const QString &card : cards) {
        if (!card.contains("BEGIN:VCARD")) continue;

        QString name;
        QStringList numbers;

        const QStringList lines = card.split('\n');
        for (const QString &rawLine : lines) {
            QString line = rawLine.trimmed();
            if (line.startsWith("FN:")) {
                name = line.mid(3).trimmed();
            } else if (line.startsWith("TEL")) {
                // Parse TEL;CELL:xxx or TEL;VOICE:xxx etc.
                int colonPos = line.indexOf(':');
                if (colonPos != -1) {
                    QString num = line.mid(colonPos + 1).trimmed();
                    if (!num.isEmpty() && !numbers.contains(num)) {
                        numbers.append(num);
                    }
                }
            }
        }

        // Only add contacts that have a name and at least one number
        if (!name.isEmpty() && !numbers.isEmpty()) {
            contacts.append({name, numbers});
        }
    }

    // Sort alphabetically by name
    std::sort(contacts.begin(), contacts.end(), [](const ContactsModel::Contact &a, const ContactsModel::Contact &b) {
        return a.name.toLower() < b.name.toLower();
    });

    return contacts;
}

static QList<RecentsModel::RecentCall> parseVCardCallHistory(const QString &vcfContent, const QString &type)
{
    QList<RecentsModel::RecentCall> calls;
    const QStringList cards = vcfContent.split("END:VCARD", Qt::SkipEmptyParts);

    for (const QString &card : cards) {
        if (!card.contains("BEGIN:VCARD")) continue;

        RecentsModel::RecentCall call;
        call.type = type;

        const QStringList lines = card.split('\n');
        for (const QString &rawLine : lines) {
            QString line = rawLine.trimmed();
            if (line.startsWith("FN:")) {
                call.name = line.mid(3).trimmed();
            } else if (line.startsWith("TEL")) {
                int colonPos = line.indexOf(':');
                if (colonPos != -1) {
                    call.number = line.mid(colonPos + 1).trimmed();
                }
            } else if (line.startsWith("X-IRMC-CALL-DATETIME")) {
                // Parse X-IRMC-CALL-DATETIME;RECEIVED:20260517T123006
                int colonPos = line.indexOf(':');
                if (colonPos != -1) {
                    QString dtStr = line.mid(colonPos + 1).trimmed();
                    QDateTime dt = QDateTime::fromString(dtStr, "yyyyMMdd'T'HHmmss");
                    if (dt.isValid()) {
                        call.rawTime = dt;
                        QDateTime now = QDateTime::currentDateTime();
                        qint64 daysDiff = dt.daysTo(now);
                        if (daysDiff == 0) {
                            call.time = dt.toString("h:mm AP");
                        } else if (daysDiff == 1) {
                            call.time = "Yesterday " + dt.toString("h:mm AP");
                        } else if (daysDiff < 7) {
                            call.time = dt.toString("dddd h:mm AP");
                        } else {
                            call.time = dt.toString("MMM d, h:mm AP");
                        }
                    }
                }
            }
        }

        if (!call.number.isEmpty()) {
            if (call.name.isEmpty()) call.name = call.number;
            calls.append(call);
        }
    }
    return calls;
}

static QString normalizePhoneNumber(const QString &number)
{
    QString normalized;
    normalized.reserve(number.size());
    for (const QChar ch : number) {
        if (ch.isDigit()) {
            normalized.append(ch);
        }
    }
    return normalized;
}



class LinuxBluezPhoneBackend : public IPhoneBackend {
    Q_OBJECT
public:
    LinuxBluezPhoneBackend(PhoneController *controller) : IPhoneBackend(controller) {
        if (!QDBusConnection::systemBus().isConnected()) {
            qWarning() << "PhoneBackend: Cannot connect to D-Bus system bus";
            return;
        }

        QDBusConnection::systemBus().connect("org.bluez", "/", "org.freedesktop.DBus.ObjectManager",
                                             "InterfacesAdded", this, SLOT(scanForPhone()));
        QDBusConnection::systemBus().connect("org.bluez", "/", "org.freedesktop.DBus.ObjectManager",
                                             "InterfacesRemoved", this, SLOT(scanForPhone()));

        m_scanTimer = new QTimer(this);
        connect(m_scanTimer, &QTimer::timeout, this, &LinuxBluezPhoneBackend::scanForPhone);
        m_scanTimer->start(5000);

        m_ringPlayer = new QMediaPlayer(this);
        m_ringAudioOutput = new QAudioOutput(this);
        m_ringPlayer->setAudioOutput(m_ringAudioOutput);
        m_ringPlayer->setSource(QUrl::fromLocalFile("/usr/share/sounds/freedesktop/stereo/phone-incoming-call.oga"));
        m_ringPlayer->setLoops(QMediaPlayer::Infinite);
        m_ringAudioOutput->setVolume(1.0);

        findActivePhone();
    }

    void dial(const QString &number) override {
        QString modemPath = findOfonoModem();
        if (modemPath.isEmpty()) {
            qWarning() << "PhoneBackend: No oFono modem found, cannot dial";
            return;
        }
        attachVoiceCallManager(modemPath);
        qDebug() << "PhoneBackend: Dialing" << number << "via oFono modem" << modemPath;

        QDBusInterface vcm("org.ofono", modemPath, "org.ofono.VoiceCallManager", QDBusConnection::systemBus());
        QDBusReply<QDBusObjectPath> reply = vcm.call("Dial", number, QString(""));
        if (reply.isValid()) {
            m_activeCallPath = reply.value().path();
            qDebug() << "PhoneBackend: Call started:" << m_activeCallPath;
            m_controller->setCallState("dialing", number);
            refreshCalls();
        } else {
            qWarning() << "PhoneBackend: Dial failed:" << reply.error().message();
        }
    }

    void hangup() override {
        QString modemPath = findOfonoModem();
        if (modemPath.isEmpty()) {
            // Simulation fallback
            clearCallState();
            return;
        }

        attachVoiceCallManager(modemPath);

        QDBusInterface vcm("org.ofono", modemPath, "org.ofono.VoiceCallManager", QDBusConnection::systemBus());
        vcm.call("HangupAll");
        m_activeCallPath.clear();
        qDebug() << "PhoneBackend: Hung up all calls";
        refreshCalls();
    }

    void answer() override {
        // Find an incoming or waiting call to answer via DBus/oFono
        for (auto it = m_calls.cbegin(); it != m_calls.cend(); ++it) {
            QString state = it.value().state.toLower();
            if (state == "incoming" || state == "waiting") {
                QDBusInterface callInterface("org.ofono", it.value().path, "org.ofono.VoiceCall", QDBusConnection::systemBus());
                callInterface.call("Answer");
                qDebug() << "PhoneBackend: Answered incoming call via DBus:" << it.value().path;
                return;
            }
        }

        // For testing/simulation fallback: if no active calls are registered, transition to active
        if (m_calls.isEmpty() && m_controller->callState() == "incoming") {
            qDebug() << "PhoneBackend: Simulating answering incoming call";
            m_controller->setCallState("active", m_controller->callerNumber());
        }
    }

private slots:
    void scanForPhone() {
        if (m_devicePath.isEmpty() || !m_controller->connected()) {
            findActivePhone();
        } else if (m_modemPath.isEmpty()) {
            attachVoiceCallManager(findOfonoModem());
        }
    }

    void handlePropertiesChanged(const QString &interface, const QVariantMap &changedProps, const QStringList &) {
        if (interface == "org.bluez.Device1") {
            if (changedProps.contains("Connected")) {
                bool connected = changedProps["Connected"].toBool();
                if (!connected) {
                    m_devicePath.clear();
                    m_deviceAddress.clear();
                    clearCallState();
                    m_controller->setConnectedStatus(false, "No Phone Connected");
                } else {
                    findActivePhone();
                }
            }
        }
    }

    void handleCallAdded(const QDBusObjectPath &path, const QVariantMap &properties) {
        Q_UNUSED(path);
        Q_UNUSED(properties);
        refreshCalls();
    }

    void handleCallRemoved(const QDBusObjectPath &path) {
        Q_UNUSED(path);
        refreshCalls();
    }

    void handleCallPropertyChanged(const QString &property, const QDBusVariant &value) {
        Q_UNUSED(property);
        Q_UNUSED(value);
        refreshCalls();
    }

    void onPbapTransferComplete() {
        // Parse phonebook
        QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/phonebook";
        QString pbFile = cacheDir + "/pb.vcf";
        if (QFile::exists(pbFile)) {
            QFile f(pbFile);
            if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QString content = QTextStream(&f).readAll();
                f.close();
                auto contacts = parseVCardContacts(content);
                qDebug() << "PhoneBackend: Parsed" << contacts.size() << "contacts from phonebook";
                m_controller->updateContacts(contacts);
            }
        }

        // Parse call history
        QList<RecentsModel::RecentCall> allCalls;
        for (const auto &pair : QList<QPair<QString,QString>>{{"ich","incoming"},{"och","outgoing"},{"mch","missed"}}) {
            QString file = cacheDir + "/" + pair.first + ".vcf";
            if (QFile::exists(file)) {
                QFile f(file);
                if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                    QString content = QTextStream(&f).readAll();
                    f.close();
                    auto calls = parseVCardCallHistory(content, pair.second);
                    qDebug() << "PhoneBackend: Parsed" << calls.size() << pair.second << "calls";
                    allCalls.append(calls);
                }
            }
        }

        // Sort all recents by time (newest first) using the rawTime parsed from the vCards
        std::sort(allCalls.begin(), allCalls.end(), [](const RecentsModel::RecentCall &a, const RecentsModel::RecentCall &b) {
            return a.rawTime > b.rawTime;
        });

        m_controller->updateRecents(allCalls);
    }

private:
    struct CallInfo {
        QString path;
        QString number;
        QString state;
    };

    void attachVoiceCallManager(const QString &modemPath) {
        if (m_modemPath == modemPath) return;

        if (!m_modemPath.isEmpty()) {
            QDBusConnection::systemBus().disconnect("org.ofono", m_modemPath, "org.ofono.VoiceCallManager",
                                                   "CallAdded", this, SLOT(handleCallAdded(QDBusObjectPath, QVariantMap)));
            QDBusConnection::systemBus().disconnect("org.ofono", m_modemPath, "org.ofono.VoiceCallManager",
                                                   "CallRemoved", this, SLOT(handleCallRemoved(QDBusObjectPath)));
        }

        m_modemPath = modemPath;
        clearCallState();

        if (m_modemPath.isEmpty()) return;

        QDBusConnection::systemBus().connect("org.ofono", m_modemPath, "org.ofono.VoiceCallManager",
                                             "CallAdded", this, SLOT(handleCallAdded(QDBusObjectPath, QVariantMap)));
        QDBusConnection::systemBus().connect("org.ofono", m_modemPath, "org.ofono.VoiceCallManager",
                                             "CallRemoved", this, SLOT(handleCallRemoved(QDBusObjectPath)));
        refreshCalls();
    }

    void refreshCalls() {
        for (auto it = m_calls.cbegin(); it != m_calls.cend(); ++it) {
            QDBusConnection::systemBus().disconnect("org.ofono", it.value().path, "org.ofono.VoiceCall",
                                                   "PropertyChanged", this, SLOT(handleCallPropertyChanged(QString, QDBusVariant)));
        }
        m_calls.clear();

        if (m_modemPath.isEmpty()) {
            updateCallStateFromCalls();
            return;
        }

        QDBusInterface vcm("org.ofono", m_modemPath, "org.ofono.VoiceCallManager", QDBusConnection::systemBus());
        QDBusMessage reply = vcm.call("GetCalls");
        if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
            updateCallStateFromCalls();
            return;
        }

        const QDBusArgument &arg = reply.arguments().first().value<QDBusArgument>();
        arg.beginArray();
        while (!arg.atEnd()) {
            arg.beginStructure();
            QDBusObjectPath path;
            QVariantMap props;
            arg >> path >> props;
            arg.endStructure();

            CallInfo info;
            info.path = path.path();
            info.state = props.value("State").toString();
            info.number = props.value("LineIdentification").toString();
            if (info.number.isEmpty()) {
                info.number = props.value("IncomingLine").toString();
            }

            m_calls.insert(info.path, info);
            QDBusConnection::systemBus().connect("org.ofono", info.path, "org.ofono.VoiceCall",
                                                 "PropertyChanged", this, SLOT(handleCallPropertyChanged(QString, QDBusVariant)));
        }
        arg.endArray();

        updateCallStateFromCalls();
    }

    int callStatePriority(const QString &state) const {
        const QString normalized = state.toLower();
        if (normalized == "incoming" || normalized == "waiting") return 5;
        if (normalized == "dialing" || normalized == "alerting") return 4;
        if (normalized == "active") return 3;
        if (normalized == "held") return 2;
        if (normalized == "disconnected") return 1;
        return 0;
    }

    void updateCallStateFromCalls() {
        if (m_calls.isEmpty()) {
            setRinging(false);
            if (m_scoAudioActive) {
                requestScoAudio(false);
            }
            m_controller->setCallState("idle");
            return;
        }

        const CallInfo *bestCall = nullptr;
        int bestPriority = -1;
        for (auto it = m_calls.cbegin(); it != m_calls.cend(); ++it) {
            int priority = callStatePriority(it.value().state);
            if (priority > bestPriority) {
                bestPriority = priority;
                bestCall = &it.value();
            }
        }

        if (!bestCall) {
            setRinging(false);
            if (m_scoAudioActive) {
                requestScoAudio(false);
            }
            m_controller->setCallState("idle");
            return;
        }

        QString state = bestCall->state.toLower();
        if (state == "waiting") state = "incoming";
        if (state.isEmpty()) state = "unknown";

        m_controller->setCallState(state, bestCall->number);
        setRinging(state == "incoming");

        // Automatically route call audio to the IVI
        if (!m_scoAudioActive) {
            requestScoAudio(true);
        }
    }

    void setRinging(bool ringing) {
        if (ringing == m_isRinging) return;
        m_isRinging = ringing;
        if (m_ringPlayer) {
            if (ringing) {
                m_ringPlayer->play();
                qDebug() << "PhoneBackend: Ringtone playing started";
            } else {
                m_ringPlayer->stop();
                qDebug() << "PhoneBackend: Ringtone playing stopped";
            }
        }
    }

    void clearCallState() {
        for (auto it = m_calls.cbegin(); it != m_calls.cend(); ++it) {
            QDBusConnection::systemBus().disconnect("org.ofono", it.value().path, "org.ofono.VoiceCall",
                                                   "PropertyChanged", this, SLOT(handleCallPropertyChanged(QString, QDBusVariant)));
        }
        m_calls.clear();
        setRinging(false);
        if (m_scoAudioActive) {
            requestScoAudio(false);
        }
        m_controller->setCallState("idle");
    }

    void findActivePhone() {
        QString newDevicePath;
        QString newDeviceName;
        QString newDeviceAddress;

        std::function<void(const QString &)> walkTree = [&](const QString &path) {
            QDBusInterface node("org.bluez", path, "org.freedesktop.DBus.Introspectable", QDBusConnection::systemBus());
            QDBusReply<QString> xmlRep = node.call("Introspect");
            if (!xmlRep.isValid()) return;

            QString xml = xmlRep.value();

            // Check if this node is a connected device
            QDBusInterface props("org.bluez", path, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
            QDBusReply<QVariant> connRep = props.call("Get", "org.bluez.Device1", "Connected");
            if (connRep.isValid() && connRep.value().toBool()) {
                newDevicePath = path;
                QDBusReply<QVariant> nameRep = props.call("Get", "org.bluez.Device1", "Alias");
                if (nameRep.isValid()) {
                    newDeviceName = nameRep.value().toString();
                } else {
                    nameRep = props.call("Get", "org.bluez.Device1", "Name");
                    if (nameRep.isValid()) newDeviceName = nameRep.value().toString();
                }
                QDBusReply<QVariant> addrRep = props.call("Get", "org.bluez.Device1", "Address");
                if (addrRep.isValid()) {
                    newDeviceAddress = addrRep.value().toString();
                }
                return;
            }

            int pos = 0;
            while ((pos = xml.indexOf("<node name=\"", pos)) != -1) {
                pos += 12;
                int end = xml.indexOf("\"", pos);
                if (end == -1) break;
                QString child = xml.mid(pos, end - pos);
                pos = end;
                walkTree((path == "/") ? "/" + child : path + "/" + child);
                if (!newDevicePath.isEmpty()) return;
            }
        };

        walkTree("/org/bluez");

        if (newDevicePath != m_devicePath && !newDevicePath.isEmpty()) {
            if (!m_devicePath.isEmpty()) {
                QDBusConnection::systemBus().disconnect("org.bluez", m_devicePath, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                                                      this, SLOT(handlePropertiesChanged(QString, QVariantMap, QStringList)));
            }

            m_devicePath = newDevicePath;
            m_deviceAddress = newDeviceAddress;
            m_controller->setConnectedStatus(true, newDeviceName);
            attachVoiceCallManager(findOfonoModem());

            QDBusConnection::systemBus().connect("org.bluez", m_devicePath, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                                                 this, SLOT(handlePropertiesChanged(QString, QVariantMap, QStringList)));

            syncPhonebook();
        } else if (newDevicePath.isEmpty() && !m_devicePath.isEmpty()) {
            m_devicePath.clear();
            m_deviceAddress.clear();
            clearCallState();
            m_controller->setConnectedStatus(false, "No Phone Connected");
        }
    }

    QString findOfonoModem() {
        // Find an oFono modem matching our connected device address
        // The modem path format is: /hfp/org/bluez/hci0/dev_XX_XX_XX_XX_XX_XX
        if (!m_deviceAddress.isEmpty()) {
            QString addrUnderscore = m_deviceAddress;
            addrUnderscore.replace(':', '_');
            QString modemPath = "/hfp/org/bluez/hci0/dev_" + addrUnderscore;

            // Verify it exists and is powered
            QDBusInterface modem("org.ofono", modemPath, "org.ofono.Modem", QDBusConnection::systemBus());
            if (modem.isValid()) {
                QDBusReply<QVariantMap> props = modem.call("GetProperties");
                if (props.isValid() && props.value()["Powered"].toBool()) {
                    return modemPath;
                }
            }
        }

        // Fallback: scan all oFono modems
        QDBusInterface manager("org.ofono", "/", "org.ofono.Manager", QDBusConnection::systemBus());
        QDBusMessage reply = manager.call("GetModems");
        if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
            const QDBusArgument &arg = reply.arguments().first().value<QDBusArgument>();
            arg.beginArray();
            while (!arg.atEnd()) {
                arg.beginStructure();
                QDBusObjectPath path;
                QVariantMap props;
                arg >> path >> props;
                arg.endStructure();
                if (props["Powered"].toBool() && props["Type"].toString() == "hfp") {
                    return path.path();
                }
            }
            arg.endArray();
        }
        return QString();
    }

    void syncPhonebook() {
        if (m_deviceAddress.isEmpty()) return;

        // Run the PBAP sync in a background process to avoid blocking the UI
        QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/phonebook";
        QDir().mkpath(cacheDir);

        QString script = QString(
            "import dbus, time, os, sys\n"
            "bus = dbus.SessionBus()\n"
            "client = dbus.Interface(bus.get_object('org.bluez.obex', '/org/bluez/obex'), 'org.bluez.obex.Client1')\n"
            "try:\n"
            "    session_path = client.CreateSession('%1', {'Target': dbus.String('pbap')})\n"
            "    time.sleep(2)\n"
            "    pb = dbus.Interface(bus.get_object('org.bluez.obex', session_path), 'org.bluez.obex.PhonebookAccess1')\n"
            "    for folder, filename in [('pb', 'pb.vcf'), ('ich', 'ich.vcf'), ('och', 'och.vcf'), ('mch', 'mch.vcf')]:\n"
            "        try:\n"
            "            pb.Select('int', folder)\n"
            "            target = '%2/' + filename\n"
            "            transfer_path, props = pb.PullAll(target, {})\n"
            "            time.sleep(3)\n"
            "        except Exception as e:\n"
            "            print('Error pulling ' + folder + ': ' + str(e), file=sys.stderr)\n"
            "    client.RemoveSession(session_path)\n"
            "except Exception as e:\n"
            "    print('PBAP session error: ' + str(e), file=sys.stderr)\n"
        ).arg(m_deviceAddress, cacheDir);

        QProcess *proc = new QProcess(this);
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc](int exitCode, QProcess::ExitStatus) {
            qDebug() << "PhoneBackend: PBAP sync finished with exit code" << exitCode;
            QString err = proc->readAllStandardError();
            if (!err.isEmpty()) qWarning() << "PBAP errors:" << err;
            onPbapTransferComplete();
            proc->deleteLater();
        });

        proc->start("python3", {"-c", script});
        qDebug() << "PhoneBackend: Started PBAP sync for" << m_deviceAddress;
    }

    // -- SCO Audio Routing --
    // Connects or disconnects the SCO audio link so call audio
    // plays through the IVI (laptop speakers) instead of the phone.
    void requestScoAudio(bool active) {
        if (active == m_scoAudioActive) return;
        m_scoAudioActive = active;

        QString modemPath = findOfonoModem();

        if (active) {
            qDebug() << "PhoneBackend: Requesting SCO audio link to route call to IVI";

            // Method 1: Use oFono Handsfree VoiceRecognition property to open SCO
            // This is the most reliable way to trigger the SCO audio connection
            if (!modemPath.isEmpty()) {
                QDBusInterface hf("org.ofono", modemPath, "org.ofono.Handsfree", QDBusConnection::systemBus());
                if (hf.isValid()) {
                    hf.call("SetProperty", "VoiceRecognition", QVariant::fromValue(QDBusVariant(true)));
                    qDebug() << "PhoneBackend: Triggered SCO via oFono VoiceRecognition";
                }
            }
        } else {
            qDebug() << "PhoneBackend: Releasing SCO audio link, restoring A2DP";

            // Release VoiceRecognition SCO trigger
            if (!modemPath.isEmpty()) {
                QDBusInterface hf("org.ofono", modemPath, "org.ofono.Handsfree", QDBusConnection::systemBus());
                if (hf.isValid()) {
                    hf.call("SetProperty", "VoiceRecognition", QVariant::fromValue(QDBusVariant(false)));
                }
            }
        }
    }

    QString m_devicePath;
    QString m_deviceAddress;
    QString m_activeCallPath;
    QString m_modemPath;
    QHash<QString, CallInfo> m_calls;
    QTimer *m_scanTimer = nullptr;
    QMediaPlayer *m_ringPlayer = nullptr;
    QAudioOutput *m_ringAudioOutput = nullptr;
    bool m_isRinging = false;
    bool m_scoAudioActive = false;
};

// ============================================================================
// PhoneController Implementation
// ============================================================================
PhoneController::PhoneController(QObject *parent) : QObject(parent)
{
    m_contactsModel = new ContactsModel(this);
    m_recentsModel = new RecentsModel(this);

    m_backend = new LinuxBluezPhoneBackend(this);
}

PhoneController::~PhoneController()
{
}

void PhoneController::dial(const QString &number)
{
    if (m_backend) m_backend->dial(number);
}

void PhoneController::hangup()
{
    if (m_backend) m_backend->hangup();
}

void PhoneController::answer()
{
    if (m_backend) m_backend->answer();
}

void PhoneController::setConnectedStatus(bool connected, const QString &name)
{
    if (m_connected != connected) {
        m_connected = connected;
        emit connectedChanged();
    }
    if (m_deviceName != name) {
        m_deviceName = name;
        emit deviceNameChanged();
    }
    if (!m_connected) {
        m_contactsModel->clear();
        m_recentsModel->clear();
        m_numberToName.clear();
        setCallState("idle");
    }
}

void PhoneController::updateContacts(const QList<ContactsModel::Contact> &contacts)
{
    m_contactsModel->setContacts(contacts);
    m_numberToName.clear();
    for (const auto &contact : contacts) {
        for (const auto &number : contact.numbers) {
            QString key = normalizePhoneNumber(number);
            if (!key.isEmpty() && !m_numberToName.contains(key)) {
                m_numberToName.insert(key, contact.name);
            }
        }
    }
    if (m_callState != "idle" && !m_callerNumber.isEmpty()) {
        setCallState(m_callState, m_callerNumber);
    }
}

void PhoneController::updateRecents(const QList<RecentsModel::RecentCall> &recents)
{
    m_recentsModel->setRecents(recents);
}

QString PhoneController::resolveContactName(const QString &number) const
{
    QString key = normalizePhoneNumber(number);
    if (key.isEmpty()) return QString();
    auto it = m_numberToName.find(key);
    if (it != m_numberToName.end()) return it.value();
    return QString();
}

void PhoneController::setCallState(const QString &state, const QString &number)
{
    QString nextState = state.trimmed();
    if (nextState.isEmpty()) {
        nextState = "idle";
    } else {
        nextState = nextState.toLower();
    }
    QString nextNumber = number;
    QString nextName;

    if (!nextNumber.isEmpty()) {
        nextName = resolveContactName(nextNumber);
    }

    if (nextState == "idle") {
        nextNumber.clear();
        nextName.clear();
    }

    if (m_callState != nextState) {
        m_callState = nextState;
        emit callStateChanged();
    }
    if (m_callerNumber != nextNumber) {
        m_callerNumber = nextNumber;
        emit callerNumberChanged();
    }
    if (m_callerName != nextName) {
        m_callerName = nextName;
        emit callerNameChanged();
    }
}

#include "PhoneController.moc"
