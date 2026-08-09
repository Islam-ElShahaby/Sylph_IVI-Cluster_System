#ifndef CAN_FRAME_H
#define CAN_FRAME_H

#include <cstdint>

#pragma pack(push, 1) // Ensures no struct padding issues across targets
struct CanFrame {
    uint32_t can_id;  // CAN ID (e.g., 0x0A2, 0x0A3)
    uint8_t  can_dlc; // Data length code (0-8)
    uint8_t  data[8]; // Raw payload
};
#pragma pack(pop)

static_assert(sizeof(CanFrame) == 13, "wire format is 13 bytes");

#endif // CAN_FRAME_H
