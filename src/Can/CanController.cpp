#include "CanController.h"

#include <QDebug>
#include <QLoggingCategory>
#include <QTimer>

#include <cstring>

// Off by default; trace frames with QT_LOGGING_RULES=sylph.can=true
Q_LOGGING_CATEGORY(canLog, "sylph.can")

CanController::CanController(const QString &host, quint16 port, QObject *parent)
    : QObject(parent)
    , m_host(host)
    , m_port(port)
{
    connect(&m_sock, &QTcpSocket::readyRead, this, &CanController::onReadyRead);
    connect(&m_sock, &QTcpSocket::connected, this, [this] {
        qInfo() << "[CAN] connected to" << m_host << m_port;
        Q_EMIT connectedChanged(true);
    });
    connect(&m_sock, &QTcpSocket::disconnected, this, [this] {
        m_buf.clear();
        Q_EMIT connectedChanged(false);
        QTimer::singleShot(2000, this, &CanController::tryConnect);
    });
    connect(&m_sock, &QTcpSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
        // disconnected() does not fire when the connect attempt itself failed,
        // so the retry has to be scheduled from here too. Anything still holding
        // a socket state is on its way to disconnected(), which retries there.
        if (m_sock.state() != QAbstractSocket::UnconnectedState)
            return;
        qWarning() << "[CAN]" << m_sock.errorString() << "- retrying in 2 s";
        QTimer::singleShot(2000, this, &CanController::tryConnect);
    });

    tryConnect();
}

void CanController::tryConnect()
{
    if (m_sock.state() != QAbstractSocket::UnconnectedState)
        return;
    m_sock.connectToHost(m_host, m_port);
}

bool CanController::takeFrame(QByteArray &buf, CanFrame &out)
{
    if (buf.size() < static_cast<int>(sizeof(CanFrame)))
        return false;

    std::memcpy(&out, buf.constData(), sizeof(CanFrame));
    buf.remove(0, sizeof(CanFrame));
    if (out.can_dlc > 8)
        out.can_dlc = 8;
    return true;
}

void CanController::onReadyRead()
{
    m_buf.append(m_sock.readAll());

    CanFrame f{};
    while (takeFrame(m_buf, f)) {
        QVariantList data;
        for (int i = 0; i < f.can_dlc; ++i)
            data.append(static_cast<int>(f.data[i]));
        qCDebug(canLog, "RX id=0x%03X dlc=%u data=%s", f.can_id, f.can_dlc,
                qUtf8Printable(QByteArray(reinterpret_cast<const char *>(f.data), f.can_dlc).toHex(' ')));
        Q_EMIT frameReceived(f.can_id, data);
    }
}

bool CanController::sendFrame(quint32 canId, const QVariantList &data)
{
    if (!connected())
        return false;

    CanFrame f{};
    f.can_id  = canId;
    f.can_dlc = static_cast<uint8_t>(qMin(data.size(), qsizetype(8)));
    for (int i = 0; i < f.can_dlc; ++i)
        f.data[i] = static_cast<uint8_t>(data.at(i).toUInt() & 0xFF);

    return m_sock.write(reinterpret_cast<const char *>(&f), sizeof(f)) == sizeof(f);
}
