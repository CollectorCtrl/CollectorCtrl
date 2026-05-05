# CollectorCtrl — Enterprise OpAMP Management

CollectorCtrl is a professional, high-performance management server for **OpenTelemetry Collectors**, based on the [OpAMP](https://github.com/open-telemetry/opamp-spec) protocol. It provides a centralized control plane for managing agent lifecycle, configuration, monitoring, and remote upgrades of observability fleets.

## Key Features

- **Fleet Management**: Centralized overview of all connected OpAMP agents and their supervisors.
- **Remote Configuration**: Push, roll back, and manage collector configurations at scale.
- **Health & Monitoring**: Real-time health reporting and connectivity status for the entire fleet.
- **Windows-Native Supervisor**: A specialized agent manager designed specifically for Windows Server environments.
- **Windows Service Ready**: Both the Server and Supervisor natively run as Windows Services for production stability.
- **Unified Deployment**: The Go backend serves the frontend assets directly—no Node.js needed in production.

## Architecture

CollectorCtrl consists of a high-performance **Go Backend** and a modern **React-based Web UI**.

```mermaid
graph TD
    A[OTEL Collector + Supervisor] -- WSS:4320/OpAMP --> B[CollectorCtrl Backend]
    C[Web Browser] -- HTTP:4321/UI --> B
    B -- Managed Postgres / SQLite --> E[(Metadata DB)]
```

## Production Readiness

CollectorCtrl is engineered to scale from a single lab instance to enterprise-grade fleets.

- **Dual-Storage Engine**: Supports lightweight **SQLite** for rapid development and **PostgreSQL** for high-concurrency production workloads.
- **Windows Installer**: Automated `.exe` installer via Inno Setup for easy deployment on Windows Server.
- **Upgrade Path**: Built-in database auto-migrations ensure zero data loss during version upgrades.

### Installation
For detailed setup instructions, including network requirements and default credentials, please see the [Installation & Setup Guide](docs/setup.md)

## Documentation
- [Feature Overview](docs/features.md)
- [Technical Architecture](docs/architecture.md)
- [Security & Compliance](docs/security.md)
- [Setup & Development Guide](SETUP.md)

---
*Created and maintained with love for the observability community.*
