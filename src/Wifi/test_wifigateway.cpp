// scan_results parsing self-check. Not part of the app build:
//   g++ -std=c++17 -fPIC $(pkg-config --cflags Qt6Core Qt6Network) -Isrc/Wifi \
//       src/Wifi/test_wifigateway.cpp src/Wifi/WifiGateway.cpp \
//       $(pkg-config --libs Qt6Core Qt6Network) -o /tmp/test_wifigateway && /tmp/test_wifigateway

#include "WifiGateway.h"

#include <cassert>
#include <cstdio>

int main()
{
    WifiNetwork n{};

    // Real line from the board. Note the SSID is the LAST field and may contain
    // spaces, which is why the parser splits on TAB and never on whitespace.
    assert(WifiGateway::parseScanLine(
        "00:42:68:ae:3f:95\t2437\t-45\t[WPA2-PSK-CCMP][ESS]\tITI Students", &n));
    assert(n.ssid == "ITI Students");
    assert(n.security == "WPA2");
    assert(n.signal == 100); // 2*(-45+100) = 110, clamped to the model's 0..100

    // The header line wpa_cli prints first is not a network.
    assert(!WifiGateway::parseScanLine(
        "bssid / frequency / signal level / flags / ssid\t\t\t\t", &n));

    // Hidden networks broadcast \x00; the pane cannot act on them.
    assert(!WifiGateway::parseScanLine(
        "00:42:68:ae:3f:9e\t5180\t-59\t[WPA2-EAP-CCMP][ESS]\t\\x00", &n));

    // Truncated / malformed lines must not produce a phantom entry.
    assert(!WifiGateway::parseScanLine("00:42:68:ae:3f:95\t2437\t-45", &n));
    assert(!WifiGateway::parseScanLine("", &n));
    assert(!WifiGateway::parseScanLine("a\tb\tNOTANUMBER\td\te", &n));

    // Open network: no crypto suite in the flags. Matches what nmcli shows.
    assert(WifiGateway::parseScanLine(
        "00:42:68:ae:3f:96\t2437\t-45\t[ESS]\tITI_Guest", &n));
    assert(n.security == "--");

    // WPA3/transition APs must not be reported as WPA2 - the gateway's CONNECT
    // uses key_mgmt WPA-PSK, so the label is the user's only warning.
    assert(WifiGateway::parseScanLine(
        "aa:bb:cc:dd:ee:ff\t2437\t-50\t[WPA2-PSK+SAE-CCMP][ESS]\tModernAP", &n));
    assert(n.security == "WPA3");

    // dBm -> percent, clamped at both ends.
    assert(WifiGateway::dbmToPercent(-45) == 100);  // 110 before clamping
    assert(WifiGateway::dbmToPercent(-50) == 100);
    assert(WifiGateway::dbmToPercent(-75) == 50);
    assert(WifiGateway::dbmToPercent(-100) == 0);
    assert(WifiGateway::dbmToPercent(-120) == 0);
    assert(WifiGateway::dbmToPercent(-10) == 100);

    printf("test_wifigateway OK\n");
    return 0;
}
