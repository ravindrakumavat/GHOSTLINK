# GHOSTLINK
### When the Network Disappears, the Link Remains.

GHOSTLINK is an offline-first emergency communication prototype designed to help SOS messages move between nearby phones over Bluetooth Low Energy (BLE) when normal internet connectivity is unavailable.

## The Problem

During emergencies, mobile data and internet access may be unreliable. GHOSTLINK explores a way to create and store emergency reports locally, transfer them to a nearby phone, and send them to a backend when a device with internet connectivity becomes available.

## How It Works

1. **Create an SOS:** Record emergency information such as incident details and location.
2. **Store locally:** Save the SOS in a local outbox so it can remain available offline.
3. **Discover nearby devices:** Scan for nearby BLE peers.
4. **Relay manually:** Select a discovered peer and initiate an SOS transfer.
5. **Reach the backend:** A receiving device with internet connectivity can submit the report to the FastAPI backend.
6. **Review incidents:** The backend stores reports in SQLite for retrieval by connected clients or a responder dashboard.

> **Current scope:** BLE discovery and relay are user-initiated. Autonomous background forwarding and a fully self-organizing multi-hop mesh are future work, not claimed as completed features.

## Architecture

```text
Flutter Mobile App
       |
       +--> Create SOS
       |
       +--> Local Outbox (SQLite)
       |
       +--> Scan and Select BLE Peer
                    |
                    v
             Nearby Phone
                    |
             Internet Available?
                    |
                    v
             FastAPI REST API
                    |
                    v
              SQLite Database
                    |
                    v
         Responder Dashboard / API
```

## Technology Stack

- **Mobile:** Flutter and Dart
- **Device communication:** Bluetooth Low Energy (BLE)
- **Local persistence:** SQLite
- **Backend:** Python and FastAPI
- **API format:** REST and JSON
- **API contract:** OpenAPI YAML
- **Location:** GPS/location services where available

## Repository Structure

```text
GHOSTLINK/
├── mobile/       # Flutter mobile application
├── backend/      # FastAPI service and API contract
├── docs/         # Project documentation and diagrams
├── .gitignore
└── README.md
```

## Getting Started

### Requirements

- Flutter SDK and Dart
- Python 3.10 or a compatible Python version for the listed dependencies
- Android device or emulator
- Bluetooth-capable physical devices for BLE testing
- Git

### 1. Run the Backend

Open PowerShell from the repository root:

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

When the server starts, open:

- API documentation: http://127.0.0.1:8000/docs
- OpenAPI contract: `backend/contract/resqmesh-openapi.yaml`

The backend uses a local SQLite database. Runtime database files are intentionally excluded from Git.

### 2. Run the Flutter App

Open a second terminal:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter run
```

Use a physical Android device to test Bluetooth features. Grant the required Bluetooth and location permissions when prompted.

### 3. Configure Backend Connectivity

Before testing end to end, check the mobile app's API base URL and configure it for your environment.

- Android emulator: the emulator generally needs a host-accessible address rather than `127.0.0.1` to reach a server on your computer.
- Physical phone: use your computer's reachable LAN IP address, with both devices on a suitable network.
- Ensure the backend port is reachable and any firewall rules permit the connection.

The mobile device cannot submit an SOS to the backend while it has no network path to that backend. Local storage and BLE relay are intended to help bridge that gap.

## Current Limitations

- BLE peer discovery and SOS forwarding require user interaction.
- Background autonomous relay and robust multi-hop routing are future development goals.
- Delivery depends on BLE compatibility, permissions, device availability, and connectivity at the receiving gateway.
- Emergency reporting should be tested carefully before any real-world deployment.
- This is a prototype, not a replacement for official emergency services.

## Future Work

- Reliable background relay where supported by the operating system
- More robust multi-hop routing and duplicate-message handling
- Battery-aware peer discovery
- Stronger message authentication and privacy protections
- Expanded testing across devices and network conditions
- Improved responder workflows and deployment documentation

## Contributing

Contributions, issue reports, and suggestions are welcome. Please describe reproduction steps for bugs and clearly identify whether a feature is implemented or proposed.

## Disclaimer

GHOSTLINK is an experimental emergency-communication prototype. Do not rely on it as the sole method of contacting emergency services.

## License

No license has been selected yet. Unless a license is added, the project should be treated as having all rights reserved by its copyright holder.
