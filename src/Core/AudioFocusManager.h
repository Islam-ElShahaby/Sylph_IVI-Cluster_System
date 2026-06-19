#ifndef AUDIOFOCUSMANAGER_H
#define AUDIOFOCUSMANAGER_H

#include <QObject>
#include <QTimer>

class BluetoothController;
class RadioController;
class LocalMediaController;
class PhoneController;

class AudioFocusManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isNavigationPromptActive READ isNavigationPromptActive NOTIFY navigationPromptActiveChanged)
    Q_PROPERTY(bool isCallInterruptionActive READ isCallInterruptionActive NOTIFY callInterruptionActiveChanged)

public:
    explicit AudioFocusManager(BluetoothController *bt,
                               RadioController *radio,
                               LocalMediaController *localMedia,
                               PhoneController *phone,
                               QObject *parent = nullptr);

    bool isNavigationPromptActive() const { return m_navPromptActive; }
    bool isCallInterruptionActive() const { return m_callInterruptionActive; }

    // Navigation Ducking Trigger
    Q_INVOKABLE void startNavigationPrompt(int durationMs = 3000);
    Q_INVOKABLE void stopNavigationPrompt();

signals:
    void navigationPromptActiveChanged();
    void callInterruptionActiveChanged();
    void audioDucked(const QString &source, int oldVol, int newVol);
    void audioRestored(const QString &source, int vol);

private slots:
    void handleCallStateChanged();
    void handleNavigationPromptTimeout();

private:
    void duckAudio();
    void restoreAudio();
    void pauseAudioForCall();
    void resumeAudioPostCall();

    BluetoothController *m_bt;
    RadioController *m_radio;
    LocalMediaController *m_local;
    PhoneController *m_phone;

    QTimer *m_navTimer;
    bool m_navPromptActive = false;
    bool m_callInterruptionActive = false;

    // States saved during Phone Call interruptions
    bool m_pausedBtByCall = false;
    bool m_pausedLocalMediaByCall = false;
    bool m_mutedRadioByCall = false;
    int m_preCallRadioVolume = 80;
    int m_preCallBtVolume = 100;
    int m_preCallLocalVolume = 80;

    // States saved during Navigation Ducking
    bool m_isDucked = false;
    int m_preDuckBtVolume = 100;
    int m_preDuckLocalVolume = 80;
    int m_preDuckRadioVolume = 80;
};

#endif // AUDIOFOCUSMANAGER_H
