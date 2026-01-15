# VPN Manager for Keenetic Router

Web interface to enable/disable VPN interfaces on Keenetic routers.

## Features

- View router device name and model
- See VPN interface status (enabled/disabled)
- Toggle VPN interface with one click
- View all available VPN interfaces

## Setup

1. Copy environment file:
   ```bash
   cp env.example .env
   ```

2. Edit `.env` with your Keenetic router credentials:
   ```
   KEENETIC_HOST=192.168.1.1
   KEENETIC_LOGIN=admin
   KEENETIC_PASSWORD=your_password
   ```

3. Start with Docker Compose:
   ```bash
   docker compose up
   ```

4. Open http://localhost:3000 in your browser.

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `KEENETIC_HOST` | Router IP address | 192.168.1.1 |
| `KEENETIC_LOGIN` | Router admin login | admin |
| `KEENETIC_PASSWORD` | Router admin password | (required) |
| `VPN_POLICY` | VPN policy name | !WG1 |

## API Endpoints

- `GET /api/status` - Get router info and VPN status
- `GET /api/interfaces` - List available VPN interfaces
- `POST /api/toggle` - Toggle VPN interface
- `POST /api/enable` - Enable VPN interface
- `POST /api/disable` - Disable VPN interface

## Tech Stack

- **Backend**: Ruby (Sinatra) with Typhoeus HTTP client
- **Frontend**: React with Vite
- **Infrastructure**: Docker Compose
