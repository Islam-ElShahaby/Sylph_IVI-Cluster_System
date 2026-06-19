#pragma once

#include <QObject>

class VehicleController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool doorFL READ doorFL WRITE setDoorFL NOTIFY doorFLChanged)
    Q_PROPERTY(bool doorFR READ doorFR WRITE setDoorFR NOTIFY doorFRChanged)
    Q_PROPERTY(bool doorRL READ doorRL WRITE setDoorRL NOTIFY doorRLChanged)
    Q_PROPERTY(bool doorRR READ doorRR WRITE setDoorRR NOTIFY doorRRChanged)
    Q_PROPERTY(bool   anyDoorOpen   READ anyDoorOpen   NOTIFY anyDoorOpenChanged)
    Q_PROPERTY(quint8 doorMask      READ doorMask      NOTIFY doorMaskChanged)
    Q_PROPERTY(bool   uartAvailable READ uartAvailable NOTIFY uartAvailableChanged)

public:
    explicit VehicleController(QObject *parent = nullptr);

    bool doorFL() const { return m_doorFL; }
    bool doorFR() const { return m_doorFR; }
    bool doorRL() const { return m_doorRL; }
    bool doorRR() const { return m_doorRR; }
    bool anyDoorOpen()   const { return m_anyDoorOpen; }
    bool uartAvailable() const { return m_uartAvailable; }

    // bit3=FL  bit2=FR  bit1=RL  bit0=RR
    quint8 doorMask() const {
        return (m_doorFL ? 8 : 0) | (m_doorFR ? 4 : 0)
             | (m_doorRL ? 2 : 0) | (m_doorRR ? 1 : 0);
    }

public Q_SLOTS:
    void setDoorFL(bool open);
    void setDoorFR(bool open);
    void setDoorRL(bool open);
    void setDoorRR(bool open);
    void setUartAvailable(bool available);
    // Set all four doors atomically from a 4-bit mask (bit3=FL ... bit0=RR).
    // Only emits per-door signals for bits that actually changed.
    void setDoorStateMask(quint8 mask);

Q_SIGNALS:
    void doorFLChanged(bool open);
    void doorFRChanged(bool open);
    void doorRLChanged(bool open);
    void doorRRChanged(bool open);
    void anyDoorOpenChanged(bool open);
    void doorMaskChanged(quint8 mask);
    void uartAvailableChanged(bool available);

private:
    bool m_doorFL      = false;
    bool m_doorFR      = false;
    bool m_doorRL      = false;
    bool m_doorRR      = false;
    bool m_anyDoorOpen = false;
    bool m_uartAvailable = false;

    void emitAnyDoorChanged();
};
