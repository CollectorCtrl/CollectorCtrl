# CollectorCtrl: Feature Overview

CollectorCtrl is the definitive, enterprise-grade platform for OpenTelemetry (OTel) fleet governance. Built on the industry-standard **OpAMP** (Open Agent Management Protocol), it shifts telemetry pipeline administration from manual, error-prone node-by-node edits to a centralized, policy-driven control plane — ensuring absolute configuration integrity, drift prevention, and unified governance.

## Platform Capabilities

### 1. Dynamic Target Policies

**Category:** Fleet Orchestration

Apply Kubernetes-style label selectors to target precise collector rings. When an agent's attributes match a policy selector (e.g., `env: production`), the Supervisor agent hot-reloads the pipeline in real time via the OpAMP WebSocket channel — **0ms pipeline downtime on config push**.

- **matchLabels Targeting**: Define policies that match agents by environment, service, host, or any custom attribute.
- **OpAMP Policy Push**: Configuration delivery is executed over the encrypted `wss://` control channel.
- **Hot-Reload**: No service restarts required. Pipelines are reconfigured in place.

---

### 2. Drift Prevention

**Category:** Configuration Integrity

Stop fighting configuration sprawl. CollectorCtrl is the **single source of truth** — it continuously validates edge configurations against defined policies and auto-corrects any divergence.

- **Indisputable Source of Truth**: Any manual on-disk configuration edits on agent nodes are instantly overwritten by the Supervisor with the server's authorized snapshot.
- **Continuous Reconciliation**: The Supervisor's Local Drift Guardian watches file integrity and triggers reconciliation automatically.
- **Real-Time Sync Status**: The Admin UI shows each agent's sync state — `In sync`, `Reconciling`, or `Drifted`.

---

### 3. Atomic Versioning & Canary Rollouts

**Category:** Version Control

Every YAML edit is SHA-hashed and versioned. Deploy changes to a **canary ring** first, validate behavior under real load, then promote — or **rollback in under 1 second** with a single click.

- **SHA-Hashed Versions**: Immutable, content-addressable configuration snapshots.
- **Canary Rings**: Target a percentage of your fleet (e.g., 10%) before full rollout.
- **One-Click Rollback**: Instantly restore any previous configuration version across the entire fleet.

---

### 4. Hybrid Sidecar Pipelines

**Category:** Pipeline Architecture

OTel YAML configurations are already complex. Layering SIEM routing and AI processing into the same collector compounds edge complexity. CollectorCtrl lets you isolate your **observability pipeline** from your **intelligence pipeline** — a custom sidecar runs separate OTel components, protecting your core telemetry path.

- **Isolated SIEM Routing**: Route security event streams to Splunk, Elastic, or custom SIEM endpoints independently.
- **Custom OTel Components**: Run vendor-distributed or custom-compiled collector binaries as the managed sidecar process.
- **AI Pipeline Separation**: Keep AI/ML processing integrations from interfering with core observability paths.

---

### 5. OIDC Identity & SSO

**Category:** Identity & Access Management

Integrate with enterprise identity providers. Just-in-Time account provisioning and dynamic directory group-to-role mappings mean **zero manual user management**.

- **Supported Providers**: Azure AD, Okta, Auth0, and any OIDC-compliant provider.
- **Just-in-Time Provisioning**: User accounts are created automatically on first login.
- **Group-to-Role Mapping**: Directory groups are dynamically mapped to CollectorCtrl roles (Admin, Operator, Viewer).

---

### 6. SIEM OTLP Audit Streaming

**Category:** Compliance

Meet compliance requirements without bolt-on solutions. Every administrator action and data mutation is streamed in real time as **structured OTLP log events** directly into your SIEM — no custom integrations or log scrapers required.

- **Real-Time OTLP Events**: Audit events are emitted via the OpenTelemetry Protocol.
- **Compatible SIEMs**: Splunk, Elastic, Datadog, and any OTLP-compatible endpoint.
- **SOC 2 Ready**: Provides the immutable audit trail required for SOC 2 compliance audits.

---

### 7. Centralized Fleet Management

**Category:** Fleet Operations

Real-time visibility into all connected collectors across Windows, Linux, and Kubernetes.

- **Live Inventory**: See all agents, their status, version, and last heartbeat at a glance.
- **Connectivity & Health Monitoring**: Track OpAMP connection state and synchronization status per agent.
- **Resource Tagging**: Identify and filter agents by host, environment, service, or custom attributes.

---

### 8. Enterprise Role-Based Access Control (RBAC)

**Category:** Security & Governance

Fine-grained permissions enforced at the API level.

- **Admin**: Full control over the system, users, fleet configurations, and all settings.
- **Operator**: Can manage configurations and control agents, but cannot manage users or system settings.
- **Viewer**: Read-only access to fleet status and configuration history.
- **Custom Roles** *(coming soon)*: Define granular permission sets tailored to your organizational structure.

---

### 9. Cost Optimisation via Control Plane Policies

**Category:** Observability FinOps

Reduce observability spend directly at the collection layer.

- **Fleet-Wide Sampling Rates**: Define tail-sampling rules and push them to every collector instantly.
- **Drop-Filter Policies**: Strip high-volume debug traces and redundant metric cardinality fleet-wide.
- **Attribute-Scrubbing Rules**: Remove PII or high-cardinality label sets before data leaves the edge.

---

*CollectorCtrl helps enterprises scale their OpenTelemetry footprint with confidence, compliance, and minimal operational overhead. Visit [collectorctrl.com](https://collectorctrl.com) for the full documentation suite.*
