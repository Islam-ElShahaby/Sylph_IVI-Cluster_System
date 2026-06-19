#pragma once

#include <QObject>
#include <QSerialPort>
#include <QByteArray>

class VehicleController;

// -----------------------------------------------------------------------------
// DoorUartReader - reads door state from a UART-connected microcontroller.
//
// Protocol (ASCII, one line per event):
//   D<hex>\n
//   <hex> = single uppercase hex digit 0-F representing a 4-bit door mask:
//     bit3=FL  bit2=FR  bit1=RL  bit0=RR
//
// Examples:
//   D0\n -> all closed
//   D8\n -> driver door (FL) open
//   DC\n -> driver + passenger (FL+FR) open
//   DF\n -> all open
//
// On a valid frame the reader calls VehicleController::setDoorStateMask().
// Unknown lines are silently discarded.
// -----------------------------------------------------------------------------
class DoorUartReader : public QObject
{
    Q_OBJECT

public:
    explicit DoorUartReader(VehicleController *vc,
                            const QString     &portName  = QStringLiteral("/dev/ttyAMA0"),
                            qint32             baudRate   = 115200,
                            QObject           *parent    = nullptr);

private Q_SLOTS:
    void onReadyRead();
    void onErrorOccurred(QSerialPort::SerialPortError error);
    void tryOpen();

private:
    void parseLine(const QByteArray &line);

    VehicleController *m_vc;
    QSerialPort        m_port;
    QByteArray         m_buf;
    bool               m_retryPending = false;
};
