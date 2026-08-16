#ifndef WIFIGATEWAY_H
#define WIFIGATEWAY_H

#include <QString>
#include <QVector>

#include "WifiController.h"

// -----------------------------------------------------------------------------
// WifiGateway - client for the QNX host's wifi_gw service (Hypervisor/wifi_gw.c).
//
// On the hypervisor guest the IVI has no radio: QNX owns bcm0 and runs the only
// wpa_supplicant. wifi_gw exposes scan/connect/status over TCP on the private vp1
// link, and this speaks that protocol.
//
// Only used when SYLPH_WIFI_GW_HOST is set - same convention as CanController's
// SYLPH_CAN_HOST. On the RPi3, which owns its own radio, the variable is unset and
// WifiController keeps using nmcli exactly as before.
//
// Synchronous by design: every call is a sub-second request/response against a
// service one hop away, and the existing nmcli backend is blocking too (QProcess
// waitForFinished), so this matches the controller's existing threading model.
// ponytail: no signals/async here - if a slow link ever makes the UI stutter,
// that's when to move it onto a worker thread.
// -----------------------------------------------------------------------------
class WifiGateway
{
public:
    WifiGateway(const QString &host, quint16 port);

    // True if the service answered a STATUS probe. Cheap; call before using.
    bool available();

    bool scan();
    bool setRadio(bool on);
    bool connectToNetwork(const QString &ssid, const QString &password, QString *error);
    bool disconnectNetwork();

    // Parsed `wpa_cli status`. Empty ssid means not associated.
    QString connectedSsid();
    bool radioUp();

    QVector<WifiNetwork> scanResults(const QString &connectedSsid);

    // Exposed for the unit test: turns one wpa_cli scan_results line into a
    // WifiNetwork. Returns false for the header line and anything malformed.
    static bool parseScanLine(const QString &line, WifiNetwork *out);
    // dBm -> the 0..100 the model and QML already expect from nmcli's SIGNAL.
    static int dbmToPercent(int dbm);
    // wpa_supplicant flags blob -> the short label the pane shows.
    static QString securityFromFlags(const QString &flags);

private:
    // Sends one line, returns the reply. Multi-line replies are '.'-terminated by
    // the protocol; single-line ones are OK/ERR.
    QString request(const QString &line, bool *ok = nullptr);

    QString m_host;
    quint16 m_port;
};

#endif // WIFIGATEWAY_H
