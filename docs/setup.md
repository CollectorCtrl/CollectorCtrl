# Installation & Setup Guide

This guide covers the deployment of CollectorCtrl using the professional Windows installers. 

## 1. Network Requirements (Firewall)

For the fleet to communicate correctly, ensure the following ports are open on your Management Server:

| Port | Protocol | Description | Required For |
| :--- | :--- | :--- | :--- |
| **4320** | TCP / WSS | OpAMP Communication | Agent -> Server Connection |
| **4321** | TCP / HTTP | Dashboard UI | Admin Access to Dashboard |

*Note: The Supervisor Agent connects **to** the Server on port 4320. No inbound ports need to be opened on the agent machines themselves.*

---

## 2. Server Installation

1.  Download `CollectorCtrl_Setup.exe`.
2.  Run the installer as an **Administrator**.
3.  Follow the wizard to install the service.
4.  **Automatic Launch**: The service will start automatically once the installation is complete.
5.  **Verification**: Open your browser and navigate to `http://localhost:4321`. You should see the login screen.

---

## 3. Supervisor Agent Installation

Repeat these steps on every server where you want to manage an OpenTelemetry Collector:

1.  Download `CollectorCtrl_Supervisor_Setup.exe`.
2.  Run the installer as an **Administrator**.
3.  **Connection Setup**: During installation, you will be prompted for the **Server URL**. 
    *   Example: `ws://192.168.1.10:4320/v1/opamp`
4.  **Finish**: The Supervisor will install itself as a Windows Service and begin communicating with the Server immediately.

---

## 4. Initial Configuration

1.  **Login**: Access the dashboard and use the default administrative credentials:
    *   **Username**: `admin`
    *   **Password**: `admin`
    *   *Note: For security, please change your password immediately after your first login.*
2.  **Verify Fleet**: Navigate to the **Agents** page. You should see your newly installed Supervisor appearing in the list.
3.  **Deploy Config**: Use the **Configuration Editor** to push your first OTel pipeline to the agent.

---
*For advanced troubleshooting, please refer to the [Architecture Guide](architecture.md) or check the local `agent.log` on the target machine.*
