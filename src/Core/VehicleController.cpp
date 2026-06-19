#include "VehicleController.h"

VehicleController::VehicleController(QObject *parent)
    : QObject(parent)
{
}

void VehicleController::setDoorFL(bool open)
{
    if (m_doorFL == open)
        return;
    m_doorFL = open;
    emit doorFLChanged(open);
    emitAnyDoorChanged();
    emit doorMaskChanged(doorMask());
}

void VehicleController::setDoorFR(bool open)
{
    if (m_doorFR == open)
        return;
    m_doorFR = open;
    emit doorFRChanged(open);
    emitAnyDoorChanged();
    emit doorMaskChanged(doorMask());
}

void VehicleController::setDoorRL(bool open)
{
    if (m_doorRL == open)
        return;
    m_doorRL = open;
    emit doorRLChanged(open);
    emitAnyDoorChanged();
    emit doorMaskChanged(doorMask());
}

void VehicleController::setDoorRR(bool open)
{
    if (m_doorRR == open)
        return;
    m_doorRR = open;
    emit doorRRChanged(open);
    emitAnyDoorChanged();
    emit doorMaskChanged(doorMask());
}

void VehicleController::setDoorStateMask(quint8 mask)
{
    bool fl = mask & 8;
    bool fr = mask & 4;
    bool rl = mask & 2;
    bool rr = mask & 1;

    bool changed = false;
    if (m_doorFL != fl) { m_doorFL = fl; emit doorFLChanged(fl); changed = true; }
    if (m_doorFR != fr) { m_doorFR = fr; emit doorFRChanged(fr); changed = true; }
    if (m_doorRL != rl) { m_doorRL = rl; emit doorRLChanged(rl); changed = true; }
    if (m_doorRR != rr) { m_doorRR = rr; emit doorRRChanged(rr); changed = true; }

    if (!changed)
        return;

    emitAnyDoorChanged();
    emit doorMaskChanged(doorMask());
}

void VehicleController::setUartAvailable(bool available)
{
    if (m_uartAvailable == available)
        return;
    m_uartAvailable = available;
    emit uartAvailableChanged(available);
}

void VehicleController::emitAnyDoorChanged()
{
    bool newAny = m_doorFL || m_doorFR || m_doorRL || m_doorRR;
    if (newAny == m_anyDoorOpen)
        return;
    m_anyDoorOpen = newAny;
    emit anyDoorOpenChanged(newAny);
}
