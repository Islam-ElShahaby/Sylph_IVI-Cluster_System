#include "WifiGateway.h"

#include <QTcpSocket>

namespace {
constexpr int kConnectTimeoutMs = 1500;
// Generous: a SCAN sweeps every channel on both bands before wpa_cli returns.
constexpr int kReplyTimeoutMs = 8000;
}

WifiGateway::WifiGateway(const QString &host, quint16 port)
    : m_host(host)
    , m_port(port)
{
}

QString WifiGateway::request(const QString &line, bool *ok)
{
    QTcpSocket sock;
    QString reply;

    if (ok) *ok = false;

    sock.connectToHost(m_host, m_port);
    if (!sock.waitForConnected(kConnectTimeoutMs)) return reply;

    sock.write((line + "\n").toUtf8());
    if (!sock.waitForBytesWritten(kConnectTimeoutMs)) return reply;

    // A reply is either one line (OK/ERR) or a block ended by a lone ".".
    while (sock.waitForReadyRead(kReplyTimeoutMs)) {
        reply += QString::fromUtf8(sock.readAll());
        if (reply.endsWith(".\n") || reply.startsWith("OK") || reply.startsWith("ERR"))
            break;
    }

    if (ok) *ok = !reply.isEmpty();
    return reply;
}

bool WifiGateway::available()
{
    bool ok = false;
    request(QStringLiteral("STATUS"), &ok);
    return ok;
}

bool WifiGateway::scan()
{
    return request(QStringLiteral("SCAN")).startsWith("OK");
}

bool WifiGateway::setRadio(bool on)
{
    return request(on ? QStringLiteral("ENABLE") : QStringLiteral("DISABLE")).startsWith("OK");
}

bool WifiGateway::connectToNetwork(const QString &ssid, const QString &password, QString *error)
{
    // TAB separator: SSIDs and passphrases legally contain spaces, and the
    // gateway's validator rejects control characters, so a TAB can never appear
    // inside either field. Keep this in step with wifi_gw.c's split_line().
    const QString cmd = QStringLiteral("CONNECT %1\t%2").arg(ssid, password);
    const QString reply = request(cmd);

    if (reply.startsWith("OK")) return true;
    if (error) {
        *error = reply.isEmpty() ? QStringLiteral("No reply from the Wi-Fi gateway.")
                                 : reply.trimmed();
    }
    return false;
}

bool WifiGateway::disconnectNetwork()
{
    return request(QStringLiteral("DISCONNECT")).startsWith("OK");
}

QString WifiGateway::connectedSsid()
{
    const QString reply = request(QStringLiteral("STATUS"));
    const QStringList lines = reply.split('\n', Qt::SkipEmptyParts);
    QString ssid;
    bool completed = false;

    for (const QString &l : lines) {
        if (l.startsWith("ssid=")) ssid = l.mid(5).trimmed();
        // Only COMPLETED means usable; SCANNING/ASSOCIATING can still carry a
        // stale ssid= line from the network being attempted.
        if (l.startsWith("wpa_state=")) completed = l.mid(10).trimmed() == "COMPLETED";
    }
    return completed ? ssid : QString();
}

bool WifiGateway::radioUp()
{
    bool ok = false;
    const QString reply = request(QStringLiteral("STATUS"), &ok);
    // wpa_cli status fails outright when the interface is down.
    return ok && reply.contains(QStringLiteral("wpa_state="));
}

int WifiGateway::dbmToPercent(int dbm)
{
    // The model and the QML expect nmcli's 0..100 SIGNAL, but wpa_supplicant
    // reports dBm. Same mapping wpa_supplicant's own tools use.
    const int pct = 2 * (dbm + 100);
    if (pct < 0) return 0;
    if (pct > 100) return 100;
    return pct;
}

QString WifiGateway::securityFromFlags(const QString &flags)
{
    if (flags.contains(QStringLiteral("WPA3")) || flags.contains(QStringLiteral("SAE")))
        return QStringLiteral("WPA3");
    if (flags.contains(QStringLiteral("WPA2"))) return QStringLiteral("WPA2");
    if (flags.contains(QStringLiteral("WPA"))) return QStringLiteral("WPA");
    if (flags.contains(QStringLiteral("WEP"))) return QStringLiteral("WEP");
    return QStringLiteral("--"); // open; matches what nmcli prints
}

bool WifiGateway::parseScanLine(const QString &line, WifiNetwork *out)
{
    // wpa_cli scan_results: bssid \t frequency \t signal \t flags \t ssid
    const QStringList parts = line.split('\t');
    if (parts.size() < 5) return false;
    if (parts.at(0) == QStringLiteral("bssid / frequency / signal level / flags / ssid"))
        return false; // header

    const QString ssid = parts.at(4).trimmed();
    // Hidden networks broadcast an empty or \x00 SSID; the pane cannot act on
    // them, and the nmcli path drops its equivalent ("--") too.
    if (ssid.isEmpty() || ssid == QStringLiteral("\\x00")) return false;

    bool okDbm = false;
    const int dbm = parts.at(2).trimmed().toInt(&okDbm);
    if (!okDbm) return false;

    out->ssid = ssid;
    out->signal = dbmToPercent(dbm);
    out->security = securityFromFlags(parts.at(3));
    out->inUse = false;
    return true;
}

QVector<WifiNetwork> WifiGateway::scanResults(const QString &connectedSsid)
{
    QVector<WifiNetwork> networks;
    const QString reply = request(QStringLiteral("LIST"));

    for (const QString &line : reply.split('\n', Qt::SkipEmptyParts)) {
        if (line == QStringLiteral(".")) break;

        WifiNetwork n;
        if (!parseScanLine(line, &n)) continue;
        n.inUse = (!connectedSsid.isEmpty() && n.ssid == connectedSsid);

        // One SSID often appears once per band and per AP - the ITI network shows
        // up a dozen times. Collapse to the strongest, as the nmcli path does.
        bool merged = false;
        for (int i = 0; i < networks.size(); ++i) {
            if (networks[i].ssid == n.ssid) {
                if (n.inUse) networks[i].inUse = true;
                if (n.signal > networks[i].signal) networks[i].signal = n.signal;
                merged = true;
                break;
            }
        }
        if (!merged) networks.append(n);
    }
    return networks;
}
