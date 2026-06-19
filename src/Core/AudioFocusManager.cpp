#include "AudioFocusManager.h"
#include "Bluetooth/BluetoothController.h"
#include "Radio/RadioController.h"
#include "LocalMedia/LocalMediaController.h"
#include "Phone/PhoneController.h"
#include <QDebug>

AudioFocusManager::AudioFocusManager(BluetoothController *bt,
                                     RadioController *radio,
                                     LocalMediaController *localMedia,
                                     PhoneController *phone,
                                     QObject *parent)
    : QObject(parent)
    , m_bt(bt)
    , m_radio(radio)
    , m_local(localMedia)
    , m_phone(phone)
{
    m_navTimer = new QTimer(this);
    m_navTimer->setSingleShot(true);
    connect(m_navTimer, &QTimer::timeout, this, &AudioFocusManager::handleNavigationPromptTimeout);

    if (m_phone) {
        connect(m_phone, &PhoneController::callStateChanged, this, &AudioFocusManager::handleCallStateChanged);
    }
}

void AudioFocusManager::startNavigationPrompt(int durationMs)
{
    qDebug() << "[AudioFocusManager] Navigation prompt started. Duration:" << durationMs << "ms";
    
    if (m_navTimer->isActive()) {
        m_navTimer->stop();
    }

    m_navPromptActive = true;
    emit navigationPromptActiveChanged();

    duckAudio();

    m_navTimer->start(durationMs);
}

void AudioFocusManager::stopNavigationPrompt()
{
    qDebug() << "[AudioFocusManager] Navigation prompt manually stopped.";
    m_navTimer->stop();
    handleNavigationPromptTimeout();
}

void AudioFocusManager::handleNavigationPromptTimeout()
{
    qDebug() << "[AudioFocusManager] Navigation prompt finished. Restoring audio focus.";
    m_navPromptActive = false;
    emit navigationPromptActiveChanged();
    restoreAudio();
}

void AudioFocusManager::handleCallStateChanged()
{
    if (!m_phone) return;

    QString state = m_phone->callState();
    qDebug() << "[AudioFocusManager] Phone call state changed to:" << state;

    bool isActiveCallState = (state == "incoming" || state == "waiting" || 
                              state == "dialing" || state == "alerting" || 
                              state == "active" || state == "held");

    if (isActiveCallState && !m_callInterruptionActive) {
        // A new call interruption started!
        pauseAudioForCall();
    } else if (!isActiveCallState && m_callInterruptionActive) {
        // The call hung up or returned to idle
        resumeAudioPostCall();
    }
}

void AudioFocusManager::duckAudio()
{
    if (m_isDucked) return;
    if (m_callInterruptionActive) return; // Don't duck if audio is already completely paused by a call

    m_isDucked = true;

    // Save pre-duck volumes
    m_preDuckBtVolume = m_bt ? m_bt->volume() : 100;
    m_preDuckLocalVolume = m_local ? m_local->volume() : 80;
    m_preDuckRadioVolume = m_radio ? m_radio->volume() : 80;

    // Ducking logic: reduce by 70% (multiply by 0.3)
    if (m_bt && m_bt->playbackStatus() == "playing") {
        int ducked = qMax(0, qRound(m_preDuckBtVolume * 0.3));
        m_bt->setVolume(ducked);
        emit audioDucked("Bluetooth", m_preDuckBtVolume, ducked);
        qDebug() << "[AudioFocusManager] Ducking Bluetooth volume from" << m_preDuckBtVolume << "to" << ducked;
    }

    if (m_local && m_local->playbackStatus() == "playing") {
        int ducked = qMax(0, qRound(m_preDuckLocalVolume * 0.3));
        m_local->setVolume(ducked);
        emit audioDucked("LocalMedia", m_preDuckLocalVolume, ducked);
        qDebug() << "[AudioFocusManager] Ducking Local Media volume from" << m_preDuckLocalVolume << "to" << ducked;
    }

    if (m_radio && m_radio->playbackStatus() == "playing") {
        int ducked = qMax(0, qRound(m_preDuckRadioVolume * 0.3));
        m_radio->setVolume(ducked);
        emit audioDucked("Radio", m_preDuckRadioVolume, ducked);
        qDebug() << "[AudioFocusManager] Ducking Radio volume from" << m_preDuckRadioVolume << "to" << ducked;
    }
}

void AudioFocusManager::restoreAudio()
{
    if (!m_isDucked) return;

    // Restore volumes
    if (m_bt && m_bt->playbackStatus() == "playing") {
        m_bt->setVolume(m_preDuckBtVolume);
        emit audioRestored("Bluetooth", m_preDuckBtVolume);
        qDebug() << "[AudioFocusManager] Restored Bluetooth volume to" << m_preDuckBtVolume;
    }

    if (m_local && m_local->playbackStatus() == "playing") {
        m_local->setVolume(m_preDuckLocalVolume);
        emit audioRestored("LocalMedia", m_preDuckLocalVolume);
        qDebug() << "[AudioFocusManager] Restored Local Media volume to" << m_preDuckLocalVolume;
    }

    if (m_radio && m_radio->playbackStatus() == "playing") {
        m_radio->setVolume(m_preDuckRadioVolume);
        emit audioRestored("Radio", m_preDuckRadioVolume);
        qDebug() << "[AudioFocusManager] Restored Radio volume to" << m_preDuckRadioVolume;
    }

    m_isDucked = false;
}

void AudioFocusManager::pauseAudioForCall()
{
    qDebug() << "[AudioFocusManager] Centralized Interruption: Pausing all audio for phone call.";
    m_callInterruptionActive = true;
    emit callInterruptionActiveChanged();

    // If navigation is speaking, stop the prompt
    if (m_navPromptActive) {
        m_navTimer->stop();
        m_navPromptActive = false;
        emit navigationPromptActiveChanged();
        m_isDucked = false; // Bypass restore since we are pausing everything
    }

    // Save volumes
    m_preCallBtVolume = m_bt ? m_bt->volume() : 100;
    m_preCallLocalVolume = m_local ? m_local->volume() : 80;
    m_preCallRadioVolume = m_radio ? m_radio->volume() : 80;

    // 1. Bluetooth Media
    if (m_bt && m_bt->playbackStatus() == "playing") {
        m_bt->pause();
        m_pausedBtByCall = true;
        qDebug() << "[AudioFocusManager] Paused active Bluetooth streaming.";
    }

    // 2. Local Media
    if (m_local && m_local->playbackStatus() == "playing") {
        m_local->pause();
        m_pausedLocalMediaByCall = true;
        qDebug() << "[AudioFocusManager] Paused active Local Media playback.";
    }

    // 3. Radio
    if (m_radio && m_radio->playbackStatus() == "playing") {
        m_radio->pause();
        m_radio->setVolume(0); // Also mute for safety
        m_mutedRadioByCall = true;
        qDebug() << "[AudioFocusManager] Muted and paused active Radio stream.";
    }
}

void AudioFocusManager::resumeAudioPostCall()
{
    qDebug() << "[AudioFocusManager] Centralized Interruption Ended: Restoring previous audio focus.";
    
    // Restore states
    if (m_pausedBtByCall && m_bt) {
        m_bt->play();
        m_pausedBtByCall = false;
        qDebug() << "[AudioFocusManager] Resumed Bluetooth streaming.";
    }

    if (m_pausedLocalMediaByCall && m_local) {
        m_local->play();
        m_pausedLocalMediaByCall = false;
        qDebug() << "[AudioFocusManager] Resumed Local Media playback.";
    }

    if (m_mutedRadioByCall && m_radio) {
        m_radio->setVolume(m_preCallRadioVolume);
        m_radio->play();
        m_mutedRadioByCall = false;
        qDebug() << "[AudioFocusManager] Restored Radio stream and volume to" << m_preCallRadioVolume;
    }

    m_callInterruptionActive = false;
    emit callInterruptionActiveChanged();
}
