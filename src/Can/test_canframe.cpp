// Framing self-check. Not part of the app build:
//   /usr/lib/qt6/libexec/moc src/Can/CanController.h -o /tmp/moc_CanController.cpp && \
//   g++ -std=c++17 -fPIC $(pkg-config --cflags Qt6Core Qt6Network) -Isrc/Can \
//       src/Can/test_canframe.cpp src/Can/CanController.cpp /tmp/moc_CanController.cpp \
//       $(pkg-config --libs Qt6Core Qt6Network) -o /tmp/test_canframe && /tmp/test_canframe

#include "CanController.h"

#include <cassert>
#include <cstdio>

int main()
{
    QByteArray buf;
    CanFrame f{};

    // Nothing to take from a short buffer, and it is left untouched.
    buf = QByteArray(12, '\0');
    assert(!CanController::takeFrame(buf, f));
    assert(buf.size() == 12);

    // Two frames arriving in one read, the second split across reads.
    CanFrame a{0x0A2, 2, {0xDE, 0xAD}};
    CanFrame b{0x1F0, 8, {1, 2, 3, 4, 5, 6, 7, 8}};
    buf.clear();
    buf.append(reinterpret_cast<const char *>(&a), sizeof(a));
    buf.append(reinterpret_cast<const char *>(&b), 5); // partial

    assert(CanController::takeFrame(buf, f));
    assert(f.can_id == 0x0A2 && f.can_dlc == 2 && f.data[0] == 0xDE && f.data[1] == 0xAD);
    assert(!CanController::takeFrame(buf, f)); // partial frame held back

    buf.append(reinterpret_cast<const char *>(&b) + 5, sizeof(b) - 5);
    assert(CanController::takeFrame(buf, f));
    assert(f.can_id == 0x1F0 && f.can_dlc == 8 && f.data[7] == 8);
    assert(buf.isEmpty());

    // A bogus DLC from the wire is clamped, so the read loop cannot run off data[].
    CanFrame bad{0x001, 99, {}};
    buf.append(reinterpret_cast<const char *>(&bad), sizeof(bad));
    assert(CanController::takeFrame(buf, f));
    assert(f.can_dlc == 8);

    std::puts("ok");
    return 0;
}
