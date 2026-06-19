#include "AudioSettingsController.h"
#include <QProcess>
#include <QThread>
#include <thread>

AudioSettingsController::AudioSettingsController(QObject *parent) : QObject(parent) {}

void AudioSettingsController::setBass(int val) {
    if (m_bass != val) {
        m_bass = qBound(0, val, 100);
        emit bassChanged();
        applyAudioHardwareSettings();
    }
}

void AudioSettingsController::setTreble(int val) {
    if (m_treble != val) {
        m_treble = qBound(0, val, 100);
        emit trebleChanged();
        applyAudioHardwareSettings();
    }
}

void AudioSettingsController::setSubwoofer(int val) {
    if (m_subwoofer != val) {
        m_subwoofer = qBound(0, val, 100);
        emit subwooferChanged();
        applyAudioHardwareSettings();
    }
}

void AudioSettingsController::setBalance(int val) {
    if (m_balance != val) {
        m_balance = qBound(-100, val, 100);
        emit balanceChanged();
        applyAudioHardwareSettings();
    }
}

void AudioSettingsController::setFader(int val) {
    if (m_fader != val) {
        m_fader = qBound(-100, val, 100);
        emit faderChanged();
        applyAudioHardwareSettings();
    }
}

void AudioSettingsController::resetToCenter() {
    setBalance(0);
    setFader(0);
    setBass(50);
    setTreble(50);
    setSubwoofer(50);
}

void AudioSettingsController::applyAudioHardwareSettings() {
    // Capture properties by value to prevent race condition/dangling pointer
    // if the AudioSettingsController is destroyed before the detached thread finishes.
    int balance = m_balance;
    int fader = m_fader;
    int bass = m_bass;
    int treble = m_treble;
    int subwoofer = m_subwoofer;

    // Run PipeWire/PulseAudio mixer controls asynchronously in a background thread
    // to keep the main Qt UI thread 100% fluid and responsive
    std::thread([balance, fader, bass, treble, subwoofer]() {
        // 1. Fetch current master volume level dynamically using pactl
        int masterVolume = 75; // Safe default fallback
        QProcess getVolProc;
        getVolProc.start("pactl", QStringList() << "get-sink-volume" << "@DEFAULT_SINK@");
        if (getVolProc.waitForFinished(120)) {
            QString out = QString::fromUtf8(getVolProc.readAllStandardOutput());
            int pctIndex = out.indexOf('%');
            if (pctIndex != -1) {
                int start = pctIndex - 1;
                while (start >= 0 && out[start].isDigit()) {
                    start--;
                }
                bool ok = false;
                int parsedVol = out.mid(start + 1, pctIndex - start - 1).toInt(&ok);
                if (ok && parsedVol > 0) {
                    masterVolume = parsedVol;
                }
            }
        }

        // 2. Calculate balance factors (Left vs Right channel scaling)
        double leftFactor = 1.0;
        double rightFactor = 1.0;
        if (balance < 0) {
            rightFactor = (100.0 + balance) / 100.0;
        } else if (balance > 0) {
            leftFactor = (100.0 - balance) / 100.0;
        }

        // 3. Calculate fader factor (Stereo rear attenuation simulation)
        double faderFactor = 1.0;
        if (fader > 0) {
            // Attenuate both speakers if fader is moved to the back in a 2-channel setup
            faderFactor = (100.0 - fader) / 100.0;
        }

        // 4. Compute final output volumes
        int leftVolume = qBound(0, qRound(masterVolume * leftFactor * faderFactor), 100);
        int rightVolume = qBound(0, qRound(masterVolume * rightFactor * faderFactor), 100);

        // 5. Apply the volumes to the default system audio sink
        QString leftVolStr = QString("%1%").arg(leftVolume);
        QString rightVolStr = QString("%1%").arg(rightVolume);
        QProcess::execute("pactl", QStringList() << "set-sink-volume" << "@DEFAULT_SINK@" << leftVolStr << rightVolStr);

        qDebug() << "[AudioTuner] Dynamic Panning -> Left:" << leftVolStr << "Right:" << rightVolStr
                 << "| Hardware EQ -> Bass:" << bass << "Treble:" << treble << "Subwoofer:" << subwoofer;
    }).detach();
}