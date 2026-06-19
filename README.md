# Sylph — IVI Cluster System

A Qt6/QML in-vehicle infotainment (IVI) system designed for embedded Linux targets. Sylph provides a modern, glass-morphism UI for controlling core vehicle systems.

![Qt](https://img.shields.io/badge/Qt-6.8-41CD52?logo=qt) ![License](https://img.shields.io/badge/license-MIT-blue)

## Features

- **Navigation** — Mapbox-powered turn-by-turn via Bluetooth GPS
- **Climate** — HVAC dial, fan speed arc, airflow modes
- **Media** — Local media player with audio focus management
- **Radio** — FM station list with RDS-style metadata
- **Phone** — Dialer, contacts, and recents via Bluetooth HFP
- **Bluetooth** — Device pairing and connection management
- **Wi-Fi** — Network scanning and connection
- **Weather** — Live conditions via Atmos backend
- **Settings** — Display, audio, time, and system info
- **Door Status** — Real-time vehicle door state via UART

## Requirements

- Qt 6.8+
- CMake 3.16+
- Qt modules: `Quick DBus Network Multimedia Widgets SerialPort`
- Mapbox API key (for navigation)

## Build

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

## Configuration

Create a `.env` file in the project root:

```env
SYLPH_MAP_API_KEY=your_mapbox_token_here
```

> `.env` is gitignored — never commit it.

## Hardware

GPS input is read from a Bluetooth GPS receiver over a virtual serial port. See `setup_bluetooth_gps.sh` for pairing setup on Linux.

Door state is read from a UART-connected microcontroller via `DoorUartReader`.
