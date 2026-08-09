#pragma once

#include <QByteArray>
#include <QObject>
#include <QTcpSocket>
#include <QVariantList>

#include "CanFrame.h"

// -----------------------------------------------------------------------------
// CanController - TCP bridge to the QNX CAN gateway.
//
// Wire format: back-to-back 13-byte CanFrame structs, native byte order (the
// gateway does no htonl/ntohl, and both ends are little-endian ARM/x86).
//
// Reconnects every 2 s while down. QML:
//     CanController.sendFrame(0x1F0, [0x11, 0x22])
//     Connections { target: CanController; function onFrameReceived(id, data) {...} }
// -----------------------------------------------------------------------------
class CanController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit CanController(const QString &host,
                           quint16        port   = 5555,
                           QObject       *parent = nullptr);

    bool connected() const { return m_sock.state() == QAbstractSocket::ConnectedState; }

    // Pops one frame off the front of buf. Static and buffer-in/out so the
    // framing can be checked without a socket (see test_canframe.cpp).
    static bool takeFrame(QByteArray &buf, CanFrame &out);

public Q_SLOTS:
    // data: list of byte values, e.g. [0x11, 0x22]. Truncated to 8 bytes.
    bool sendFrame(quint32 canId, const QVariantList &data);

Q_SIGNALS:
    void connectedChanged(bool connected);
    void frameReceived(quint32 canId, QVariantList data);

private Q_SLOTS:
    void onReadyRead();
    void tryConnect();

private:
    QTcpSocket m_sock;
    QByteArray m_buf;
    QString    m_host;
    quint16    m_port;
};
