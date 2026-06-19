#include "DoorUartReader.h"
#include "VehicleController.h"

#include <QTimer>
#include <QDebug>

DoorUartReader::DoorUartReader(VehicleController *vc,
                               const QString     &portName,
                               qint32             baudRate,
                               QObject           *parent)
    : QObject(parent)
    , m_vc(vc)
{
    m_port.setPortName(portName);
    m_port.setBaudRate(baudRate);
    m_port.setDataBits(QSerialPort::Data8);
    m_port.setParity(QSerialPort::NoParity);
    m_port.setStopBits(QSerialPort::OneStop);
    m_port.setFlowControl(QSerialPort::NoFlowControl);

    connect(&m_port, &QSerialPort::readyRead,
            this, &DoorUartReader::onReadyRead);
    connect(&m_port, &QSerialPort::errorOccurred,
            this, &DoorUartReader::onErrorOccurred);

    tryOpen();
}

void DoorUartReader::tryOpen()
{
    m_retryPending = false;

    if (m_port.isOpen())
        m_port.close();

    if (m_port.open(QIODevice::ReadOnly)) {
        qInfo() << "DoorUartReader: opened" << m_port.portName()
                << "at" << m_port.baudRate() << "baud";
        m_vc->setUartAvailable(true);
    }
    // If open() failed it already emitted errorOccurred, which onErrorOccurred()
    // handled synchronously -- the retry timer is already scheduled from there.
    // Do NOT schedule a second timer here.
}

void DoorUartReader::onReadyRead()
{
    m_buf.append(m_port.readAll());

    int nl;
    while ((nl = m_buf.indexOf('\n')) != -1) {
        QByteArray line = m_buf.left(nl).trimmed();
        m_buf.remove(0, nl + 1);
        if (!line.isEmpty())
            parseLine(line);
    }
}

void DoorUartReader::parseLine(const QByteArray &line)
{
    // Expected format: D<hex>   e.g. "D8", "D0F" is invalid -- exactly 2 chars
    if (line.size() != 2 || line[0] != 'D')
        return;

    char hexChar = line[1];
    quint8 mask;
    if (hexChar >= '0' && hexChar <= '9')
        mask = static_cast<quint8>(hexChar - '0');
    else if (hexChar >= 'A' && hexChar <= 'F')
        mask = static_cast<quint8>(hexChar - 'A' + 10);
    else if (hexChar >= 'a' && hexChar <= 'f')
        mask = static_cast<quint8>(hexChar - 'a' + 10);
    else
        return;

    m_vc->setDoorStateMask(mask);
}

void DoorUartReader::onErrorOccurred(QSerialPort::SerialPortError error)
{
    if (error == QSerialPort::NoError)
        return;

    qWarning() << "DoorUartReader: serial error on" << m_port.portName()
               << "–" << m_port.errorString();

    // Guard: close() on an already-closed port emits NotOpenError, which would
    // recurse back here. Only close if actually open.
    if (m_port.isOpen())
        m_port.close();

    m_vc->setUartAvailable(false);

    if (!m_retryPending) {
        m_retryPending = true;
        qWarning() << "DoorUartReader: retrying in 2 s";
        QTimer::singleShot(2000, this, &DoorUartReader::tryOpen);
    }
}
