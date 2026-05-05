# CollectorCtrl: Technical Architecture

CollectorCtrl follows a distributed management architecture designed for high availability and low latency.

## Component Overview

### 1. Management Server (The "Brain")
- **Backend (Go)**: A high-performance Go application that handles OpAMP WebSocket connections and provides a RESTful API for the UI.
- **Frontend (React)**: A modern Single Page Application (SPA) for visualizing fleet status and managing configurations.
- **Storage**:
    - **SQLite (Standard)**: Zero-config, single-file database for small to medium fleets.
    - **PostgreSQL (Enterprise)**: High-concurrency database for managing 10,000+ agents.

### 2. CollectorCtrl Supervisor (The "Manager")
- A lightweight agent that runs on each target server.
- **Responsibility**: Manages the lifecycle of the OpenTelemetry Collector binary.
- **Communication**: Establishes a persistent WebSocket connection to the Management Server using the OpAMP protocol.

### 3. OpenTelemetry Collector (The "Worker")
- The standard OTel binary that performs the actual telemetry collection, processing, and exporting.
- Controlled and updated by the Supervisor.

## Data Flow & Protocol

### OpAMP Protocol
CollectorCtrl uses the **Open Agent Management Protocol (OpAMP)** to ensure standardized communication. 
- **Heartbeats**: Agents send periodic health reports and current configuration hashes.
- **Server-to-Agent**: The server pushes new configurations, upgrade instructions, or control commands (Restart/Start/Stop).
- **Agent-to-Server**: Agents report effective configurations and any errors encountered during application.

### Network Requirements (Firewall)
- **Port 4320 (Inbound)**: WebSocket endpoint for agent/supervisor communication (WSS).
- **Port 4321 (Inbound)**: User access port for the **Web UI Dashboard** and REST API. This is the port users enter in their browser to manage the fleet.

## Security Model
- **TLS Encryption**: All traffic is encrypted via TLS 1.3.
- **Mutual TLS (mTLS)**: Agents can be configured to use client certificates for strong authentication.
- **JWT Auth**: User sessions in the UI are secured via JSON Web Tokens (JWT).

---
*The architecture is designed to be "Supervisor-first," meaning the supervisor remains running and manageable even if the OTel collector binary crashes.*
