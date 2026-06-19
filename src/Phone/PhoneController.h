#ifndef PHONECONTROLLER_H
#define PHONECONTROLLER_H

#include <QObject>
#include <QAbstractListModel>
#include <QStringList>
#include <QDateTime>
#include <QHash>

// Forward declare backend interface
class IPhoneBackend;

// ============================================================================
// Contacts Model
// ============================================================================
class ContactsModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum ContactRoles {
        NameRole = Qt::UserRole + 1,
        NumbersRole
    };

    struct Contact {
        QString name;
        QStringList numbers;
    };

    explicit ContactsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setContacts(const QList<Contact> &contacts);
    void clear();

private:
    QList<Contact> m_contacts;
};

// ============================================================================
// Recents Model
// ============================================================================
class RecentsModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum RecentRoles {
        NameRole = Qt::UserRole + 1,
        NumberRole,
        TypeRole, // "incoming", "outgoing", "missed"
        TimeRole
    };

    struct RecentCall {
        QString name;
        QString number;
        QString type;
        QString time;
        QDateTime rawTime;
    };

    explicit RecentsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setRecents(const QList<RecentCall> &recents);
    void clear();

private:
    QList<RecentCall> m_recents;
};

// ============================================================================
// Phone Controller
// ============================================================================
class PhoneController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY deviceNameChanged)
    Q_PROPERTY(ContactsModel* contactsModel READ contactsModel CONSTANT)
    Q_PROPERTY(RecentsModel* recentsModel READ recentsModel CONSTANT)
    Q_PROPERTY(QString callState READ callState NOTIFY callStateChanged)
    Q_PROPERTY(QString callerName READ callerName NOTIFY callerNameChanged)
    Q_PROPERTY(QString callerNumber READ callerNumber NOTIFY callerNumberChanged)

public:
    explicit PhoneController(QObject *parent = nullptr);
    ~PhoneController();

    bool connected() const { return m_connected; }
    QString deviceName() const { return m_deviceName; }
    ContactsModel* contactsModel() const { return m_contactsModel; }
    RecentsModel* recentsModel() const { return m_recentsModel; }
    QString callState() const { return m_callState; }
    QString callerName() const { return m_callerName; }
    QString callerNumber() const { return m_callerNumber; }

    Q_INVOKABLE void dial(const QString &number);
    Q_INVOKABLE void hangup();
    Q_INVOKABLE void answer();

    // Internal Setters used by Backend
    void setConnectedStatus(bool connected, const QString &name = "");
    void updateContacts(const QList<ContactsModel::Contact> &contacts);
    void updateRecents(const QList<RecentsModel::RecentCall> &recents);
    void setCallState(const QString &state, const QString &number = QString());
    QString resolveContactName(const QString &number) const;

signals:
    void connectedChanged();
    void deviceNameChanged();
    void callStateChanged();
    void callerNameChanged();
    void callerNumberChanged();

private:
    IPhoneBackend *m_backend;
    bool m_connected = false;
    QString m_deviceName = "No Phone Connected";
    QString m_callState = "idle";
    QString m_callerName;
    QString m_callerNumber;
    QHash<QString, QString> m_numberToName;
    
    ContactsModel *m_contactsModel;
    RecentsModel *m_recentsModel;
};

#endif // PHONECONTROLLER_H
