#ifndef BLUETOOTHGPSCONTROLLER_H
#define BLUETOOTHGPSCONTROLLER_H

#include <QObject>
#include <QTimer>

class BluetoothGpsController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double latitude READ latitude NOTIFY positionChanged)
    Q_PROPERTY(double longitude READ longitude NOTIFY positionChanged)
    Q_PROPERTY(double heading READ heading NOTIFY positionChanged)
    Q_PROPERTY(double speed READ speed NOTIFY positionChanged)
    Q_PROPERTY(double altitude READ altitude NOTIFY positionChanged)
    Q_PROPERTY(int satellites READ satellites NOTIFY positionChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

public:
    explicit BluetoothGpsController(QObject *parent = nullptr);
    ~BluetoothGpsController();

    double latitude() const { return m_latitude; }
    double longitude() const { return m_longitude; }
    double heading() const { return m_heading; }
    double speed() const { return m_speed; }
    double altitude() const { return m_altitude; }
    int satellites() const { return m_satellites; }
    bool active() const { return m_active; }

signals:
    void positionChanged();
    void activeChanged();

private slots:
    void pollDevice();

private:
    void parseNmeaLine(const QByteArray &line);
    double parseNmeaCoord(const QString &raw, const QString &dir);

    int m_fd = -1;
    QTimer *m_pollTimer;
    QByteArray m_buffer;

    double m_latitude = 0.0;
    double m_longitude = 0.0;
    double m_heading = -1.0;
    double m_speed = 0.0;
    double m_altitude = 0.0;
    int m_satellites = 0;
    bool m_active = false;
};

#endif // BLUETOOTHGPSCONTROLLER_H
