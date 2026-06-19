#ifndef AUDIOSETTINGSCONTROLLER_H
#define AUDIOSETTINGSCONTROLLER_H

#include <QObject>
#include <QDebug>

class AudioSettingsController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int bass READ bass WRITE setBass NOTIFY bassChanged)
    Q_PROPERTY(int treble READ treble WRITE setTreble NOTIFY trebleChanged)
    Q_PROPERTY(int subwoofer READ subwoofer WRITE setSubwoofer NOTIFY subwooferChanged)
    Q_PROPERTY(int balance READ balance WRITE setBalance NOTIFY balanceChanged)
    Q_PROPERTY(int fader READ fader WRITE setFader NOTIFY faderChanged)

public:
    explicit AudioSettingsController(QObject *parent = nullptr);

    int bass() const { return m_bass; }
    int treble() const { return m_treble; }
    int subwoofer() const { return m_subwoofer; }
    int balance() const { return m_balance; }
    int fader() const { return m_fader; }

    Q_INVOKABLE void setBass(int val);
    Q_INVOKABLE void setTreble(int val);
    Q_INVOKABLE void setSubwoofer(int val);
    Q_INVOKABLE void setBalance(int val);
    Q_INVOKABLE void setFader(int val);
    Q_INVOKABLE void resetToCenter();

signals:
    void bassChanged();
    void trebleChanged();
    void subwooferChanged();
    void balanceChanged();
    void faderChanged();

private:
    void applyAudioHardwareSettings();

    int m_bass = 50;
    int m_treble = 50;
    int m_subwoofer = 50;
    int m_balance = 0; // -100 (Left) to 100 (Right)
    int m_fader = 0;   // -100 (Front) to 100 (Rear)
};

#endif // AUDIOSETTINGSCONTROLLER_H