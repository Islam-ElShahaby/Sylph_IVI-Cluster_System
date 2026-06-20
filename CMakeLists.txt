cmake_minimum_required(VERSION 3.16)

project(Sylph VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick DBus Network Multimedia Widgets SerialPort)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appSylph
    src/main.cpp
)

set(QML_FILES
    src/Core/Main.qml
    src/Core/HomeCard.qml
    src/Core/CircularSelector.qml
    src/Core/MediaButton.qml
    src/Core/GlassSwitch.qml
    src/Core/GlassPanel.qml
    src/Radio/RadioCard.qml
    src/Core/CardSwiper.qml
    src/Core/SidebarMenu.qml
    src/Core/GlassKeyboard.qml
    src/Navigation/NavigationCard.qml
    src/Navigation/MapActionsPanel.qml
    src/Navigation/DirectiveCard.qml
    src/Navigation/TripProgressCard.qml
    src/Bluetooth/BluetoothCard.qml
    src/Phone/DialerCard.qml
    src/Phone/ContactsCard.qml
    src/Phone/RecentsCard.qml
    src/Settings/SettingsCard.qml
    src/Settings/SettingsWifiPane.qml
    src/Settings/SettingsBluetoothPane.qml
    src/Settings/SettingsAboutPane.qml
    src/Settings/DisplaySettingsCard.qml
    src/Settings/TimeSettingsPane.qml
    src/Settings/AudioSettingsCard.qml
    src/Settings/SettingsWeatherPane.qml
    src/Weather/WeatherCard.qml
    src/LocalMedia/LocalMediaCard.qml
    src/Climate/ClimateCard.qml
    src/Climate/AcDial.qml
    src/Climate/HvacModeButton.qml
    src/Climate/HvacflowButton.qml
    src/Climate/FanSpeedArc.qml
    src/Core/DoorStatusPopup.qml
)

foreach(qml_file IN LISTS QML_FILES)
    get_filename_component(qml_name ${qml_file} NAME)
    set_source_files_properties(${qml_file} PROPERTIES QT_RESOURCE_ALIAS ${qml_name})
endforeach()

qt_add_qml_module(appSylph
    URI Sylph
    QML_FILES
        ${QML_FILES}
    SOURCES
        src/Bluetooth/BluetoothController.h
        src/Bluetooth/BluetoothController.cpp
        src/Radio/RadioController.h
        src/Radio/RadioController.cpp
        src/Radio/RadioStationsModel.h
        src/Radio/RadioStationsModel.cpp
        src/Phone/PhoneController.h
        src/Phone/PhoneController.cpp
        src/Wifi/WifiController.h
        src/Wifi/WifiController.cpp
        src/LocalMedia/LocalMediaController.h
        src/LocalMedia/LocalMediaController.cpp
        src/Core/AudioFocusManager.h
        src/Core/AudioFocusManager.cpp
        src/Navigation/BluetoothGpsController.h
        src/Navigation/BluetoothGpsController.cpp
        src/Core/AppConfig.h
        src/Core/AppConfig.cpp
        src/Core/VehicleController.h
        src/Core/VehicleController.cpp
        src/Core/DoorUartReader.h
        src/Core/DoorUartReader.cpp
        src/Settings/AudioSettingsController.h
        src/Settings/AudioSettingsController.cpp
        src/Weather/AtmosBackend.h
        src/Weather/AtmosBackend.cpp

    RESOURCES
        assets.qrc
)

target_include_directories(appSylph PRIVATE
    src
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appSylph PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appSylph
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appSylph
    PRIVATE Qt6::Quick Qt6::DBus Qt6::Network Qt6::Multimedia Qt6::Widgets Qt6::SerialPort
)

include(GNUInstallDirs)
install(TARGETS appSylph
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
