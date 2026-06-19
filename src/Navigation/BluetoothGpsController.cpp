#include "BluetoothGpsController.h"
#include <QDebug>
#include <QFileInfo>
#include <cmath>

#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

static const char* RFCOMM_DEVICE = "/dev/rfcomm0";

BluetoothGpsController::BluetoothGpsController(QObject *parent)
    : QObject(parent)
{
    m_pollTimer = new QTimer(this);
    connect(m_pollTimer, &QTimer::timeout, this, &BluetoothGpsController::pollDevice);
    m_pollTimer->start(200);
}

BluetoothGpsController::~BluetoothGpsController()
{
    if (m_pollTimer) {
        m_pollTimer->stop();
    }
    if (m_fd >= 0) {
        ::close(m_fd);
        m_fd = -1;
    }
}

void BluetoothGpsController::pollDevice()
{
    // If not open, try to open
    if (m_fd < 0) {
        if (!QFileInfo::exists(RFCOMM_DEVICE))
            return;

        // Open with O_NONBLOCK.
        // CRITICAL FIX: We MUST NOT use tcgetattr/tcsetattr on an RFCOMM device!
        // Virtual Bluetooth serial ports do not have physical baud rates.
        // Sending terminal config commands (RPN) to the Android phone causes
        // the phone's GPS app to instantly drop the connection (EOF).
        m_fd = ::open(RFCOMM_DEVICE, O_RDONLY | O_NOCTTY | O_NONBLOCK);
        if (m_fd < 0) {
            return;
        }

        qDebug() << "[BtGPS] Connected and opened" << RFCOMM_DEVICE << "fd" << m_fd;
        m_buffer.clear();

        if (!m_active) {
            m_active = true;
            emit activeChanged();
        }
    }

    // Read whatever is available
    char buf[2048];
    ssize_t totalRead = 0;

    while (true) {
        ssize_t n = ::read(m_fd, buf, sizeof(buf) - 1);
        if (n > 0) {
            m_buffer.append(buf, n);
            totalRead += n;
        } else if (n == 0) {
            // EOF -- device disconnected
            qDebug() << "[BtGPS] Device disconnected (EOF)";
            ::close(m_fd);
            m_fd = -1;
            if (m_active) {
                m_active = false;
                emit activeChanged();
            }
            return;
        } else {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                break; // No more data right now, totally normal
            }
            qDebug() << "[BtGPS] Read error:" << strerror(errno);
            ::close(m_fd);
            m_fd = -1;
            if (m_active) {
                m_active = false;
                emit activeChanged();
            }
            return;
        }
    }

    if (totalRead == 0)
        return;

    // Process complete NMEA lines
    while (true) {
        int idx = m_buffer.indexOf('\n');
        if (idx < 0)
            break;

        QByteArray line = m_buffer.left(idx).trimmed();
        m_buffer.remove(0, idx + 1);

        if (line.startsWith('$')) {
            parseNmeaLine(line);
        }
    }

    if (m_buffer.size() > 8192)
        m_buffer.clear();
}

double BluetoothGpsController::parseNmeaCoord(const QString &raw, const QString &dir)
{
    if (raw.isEmpty())
        return 0.0;

    int dotPos = raw.indexOf('.');
    if (dotPos < 0 || dotPos < 3)
        return 0.0;

    int degLen = dotPos - 2;
    double degrees = raw.left(degLen).toDouble();
    double minutes = raw.mid(degLen).toDouble();
    double result = degrees + (minutes / 60.0);

    if (dir == "S" || dir == "W")
        result = -result;

    return result;
}

void BluetoothGpsController::parseNmeaLine(const QByteArray &line)
{
    QString sentence = QString::fromLatin1(line);
    int starPos = sentence.indexOf('*');
    if (starPos > 0)
        sentence = sentence.left(starPos);

    QStringList fields = sentence.split(',');
    if (fields.size() < 3)
        return;

    QString type = fields[0];

    if (type == "$GPGGA" || type == "$GNGGA") {
        if (fields.size() < 10)
            return;

        int quality = fields[6].toInt();
        if (quality == 0)
            return;

        double lat = parseNmeaCoord(fields[2], fields[3]);
        double lon = parseNmeaCoord(fields[4], fields[5]);
        int sats = fields[7].toInt();
        double alt = fields[9].toDouble();

        if (lat != 0.0 && lon != 0.0) {
            m_latitude = lat;
            m_longitude = lon;
            m_satellites = sats;
            m_altitude = alt;

//             qDebug() << "[BtGPS] Fix:" << m_latitude << m_longitude
//                      << "Sats:" << m_satellites << "Alt:" << m_altitude;
            emit positionChanged();
        }
    }
    else if (type == "$GPRMC" || type == "$GNRMC") {
        if (fields.size() < 9)
            return;

        if (fields[2] != "A")
            return;

        double lat = parseNmeaCoord(fields[3], fields[4]);
        double lon = parseNmeaCoord(fields[5], fields[6]);

        if (lat != 0.0 && lon != 0.0) {
            m_latitude = lat;
            m_longitude = lon;

            if (!fields[7].isEmpty()) {
                m_speed = fields[7].toDouble() * 1.852; // knots to km/h
            }

            if (!fields[8].isEmpty()) {
                double track = fields[8].toDouble();
                if (track >= 0.0 && track <= 360.0) {
                    // Only update GPS track heading if we are actually moving (>2 km/h)
                    // If stationary, we rely on the internal compass ($HCHDT)
                    if (m_speed > 2.0) {
                        m_heading = track;
                    }
                }
            }

//             qDebug() << "[BtGPS] RMC:" << m_latitude << m_longitude
//                      << "Heading:" << m_heading << "Speed:" << m_speed << "km/h";
            emit positionChanged();
        }
    }
    // $HCHDT - True Heading (from phone's internal compass)
    // $HCHDT,157.7,T*2D
    else if (type == "$HCHDT") {
        if (fields.size() < 3)
            return;

        if (fields[2] != "T")
            return;

        if (!fields[1].isEmpty()) {
            double compassHeading = fields[1].toDouble();
            if (compassHeading >= 0.0 && compassHeading <= 360.0) {
                // If we are moving fast, prefer GPS track. If stationary/slow, prefer compass.
                if (m_speed <= 2.0) {
                    m_heading = compassHeading;
//                     qDebug() << "[BtGPS] Compass Heading:" << m_heading;
                     emit positionChanged();
                 }
             }
         }
    }
}
