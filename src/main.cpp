#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include "Bluetooth/BluetoothController.h"
#include "Radio/RadioController.h"
#include "Phone/PhoneController.h"
#include "Wifi/WifiController.h"
#include "LocalMedia/LocalMediaController.h"
#include "Core/AudioFocusManager.h"
#include "Navigation/BluetoothGpsController.h"
#include "Core/AppConfig.h"
#include "Settings/AudioSettingsController.h"
#include "Weather/AtmosBackend.h"
#include "Core/VehicleController.h"
#include "Core/DoorUartReader.h"
#include "Can/CanController.h"

int main(int argc, char *argv[])
{
    // Force OpenGL graphics API for RHI backend to ensure compatibility with MapLibre Native QT
    qputenv("QSG_RHI_BACKEND", "opengl");
    // NavigationCard loads the offline map style over file://, which Qt gates by default
    qputenv("QML_XHR_ALLOW_FILE_READ", "1");

    QApplication app(argc, argv);
    // Needed for QSettings (weather location/units persistence)
    QCoreApplication::setOrganizationName("Sylph");
    QCoreApplication::setApplicationName("Sylph");
    AppConfig *appConfig = new AppConfig(&app);

    // Create the controller dynamically so it lives for the app's lifetime
    BluetoothController *controller = new BluetoothController(&app);
    RadioController *radioController = new RadioController(&app);
    PhoneController *phoneController = new PhoneController(&app);
    WifiController *wifiController = new WifiController(&app);
    LocalMediaController *localMediaController = new LocalMediaController(&app);
    AudioFocusManager *audioFocusManager = new AudioFocusManager(controller, radioController, localMediaController, phoneController, &app);
    BluetoothGpsController *gpsController = new BluetoothGpsController(&app);
    AudioSettingsController *audioSettingsController = new AudioSettingsController(&app);
    AtmosBackend *weatherController = new AtmosBackend(&app);
    VehicleController *vehicleController = new VehicleController(&app);
    new DoorUartReader(vehicleController, QStringLiteral("/dev/ttyAMA0"), 115200, &app);
    const int canPort = qEnvironmentVariableIntValue("SYLPH_CAN_PORT");
    CanController *canController = new CanController(
        qEnvironmentVariable("SYLPH_CAN_HOST", QStringLiteral("10.42.0.65")),
        static_cast<quint16>(canPort > 0 ? canPort : 5555),
        &app);

    // Register it as a QML Singleton
    qmlRegisterSingletonInstance("Sylph.Bluetooth", 1, 0, "BtController", controller);
    qmlRegisterSingletonInstance("Sylph.Radio", 1, 0, "RadioController", radioController);
    qmlRegisterSingletonInstance("Sylph.Phone", 1, 0, "PhoneController", phoneController);
    qmlRegisterSingletonInstance("Sylph.Wifi", 1, 0, "WifiController", wifiController);
    qmlRegisterSingletonInstance("Sylph.LocalMedia", 1, 0, "LocalMediaController", localMediaController);
    qmlRegisterSingletonInstance("Sylph.Core", 1, 0, "AudioFocusManager", audioFocusManager);
    qmlRegisterSingletonInstance("Sylph.Core", 1, 0, "BtGpsController", gpsController);
    qmlRegisterSingletonInstance("Sylph.Core", 1, 0, "AppConfig", appConfig);
    qmlRegisterSingletonInstance("Sylph.Settings", 1, 0, "AudioSettingsController", audioSettingsController);
    qmlRegisterSingletonInstance("Sylph.Weather", 1, 0, "WeatherController", weatherController);
    qmlRegisterSingletonInstance("Sylph.Core",    1, 0, "VehicleController", vehicleController);
    qmlRegisterSingletonInstance("Sylph.Can",     1, 0, "CanController", canController);

    QQmlApplicationEngine engine;
    // No addImportPath for /usr/local/qml: a stale MapLibre plugin lives there and
    // addImportPath prepends, so it would shadow the one in the Qt prefix. The
    // MapQuickItem metaobject is file-local to whichever plugin loads, so the stale
    // copy silently defines the QML property set.

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("Sylph", "Main");

    return app.exec();
}
