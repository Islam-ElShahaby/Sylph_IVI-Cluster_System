#ifndef WIFICONTROLLER_H
#define WIFICONTROLLER_H

#include <QAbstractListModel>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>

struct WifiNetwork {
    QString ssid;
    int signal = 0;
    QString security;
    bool inUse = false;
};

class WifiNetworksModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum NetworkRole {
        SsidRole = Qt::UserRole + 1,
        SignalRole,
        SecurityRole,
        InUseRole
    };

    explicit WifiNetworksModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setNetworks(const QVector<WifiNetwork> &networks);
    const WifiNetwork *networkAt(int index) const;
    void clear();

private:
    QVector<WifiNetwork> m_networks;
};

class WifiController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(QString connectedSsid READ connectedSsid NOTIFY connectedSsidChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QAbstractListModel* networksModel READ networksModel CONSTANT)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit WifiController(QObject *parent = nullptr);

    bool enabled() const { return m_enabled; }
    bool scanning() const { return m_scanning; }
    QString connectedSsid() const { return m_connectedSsid; }
    QString lastError() const { return m_lastError; }
    QAbstractListModel *networksModel() { return m_model; }
    bool available() const { return m_available; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void connectToNetwork(const QString &ssid, const QString &password);
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void setEnabled(bool enabled);

signals:
    void enabledChanged();
    void scanningChanged();
    void connectedSsidChanged();
    void lastErrorChanged();
    void availableChanged();

private:
    void setScanning(bool scanning);
    void setLastError(const QString &error);
    void setConnectedSsid(const QString &ssid);
    void updateRadioState();
    void updateAvailable();
    void handleScanOutput(const QString &output);
    QString runNmcli(const QStringList &args, int timeoutMs, bool *ok = nullptr) const;
    QString findWifiDevice() const;
    static QStringList splitTerseLine(const QString &line);

    WifiNetworksModel *m_model;
    bool m_enabled = false;
    bool m_scanning = false;
    bool m_available = false;
    QString m_connectedSsid;
    QString m_lastError;
};

#endif // WIFICONTROLLER_H
