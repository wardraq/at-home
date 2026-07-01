## ADDED Requirements

### Requirement: Admin port isolation
The server SHALL expose Admin API and Web UI only on port 6061 bound to `127.0.0.1`.

#### Scenario: Localhost-only binding
- **WHEN** the server starts
- **THEN** port 6061 listens exclusively on `127.0.0.1` and is not reachable from the LAN

### Requirement: Admin Web UI
The server SHALL serve a minimal Web UI at `GET /` on port 6061.

#### Scenario: Dashboard display
- **WHEN** a user opens `http://127.0.0.1:6061/` in a browser
- **THEN** the page displays `serverId`, API address (`:6060`), storage path, user list, and recent uploads

### Requirement: User management
The server SHALL provide admin endpoints to create and revoke users.

#### Scenario: Create user
- **WHEN** admin sends `POST /admin/users` with `{ "name": "wardraq" }`
- **THEN** the server generates a `userId`, persists the user with status `active`, and returns `qrPayload` containing `serverId`, `userId`, and `addr` (`{lan-ip}:6060`)

#### Scenario: List users
- **WHEN** admin sends `GET /admin/users`
- **THEN** the server returns all users with `userId`, `name`, `status`, `createdAt`, `assetCount`, and `lastUploadAt`

#### Scenario: Revoke user
- **WHEN** admin sends `DELETE /admin/users/{userId}`
- **THEN** the user status becomes `revoked`, all session tokens for that user are invalidated, and existing files on disk are retained

### Requirement: QR code generation
The server SHALL generate pairing QR codes for users.

#### Scenario: JSON QR payload
- **WHEN** admin sends `GET /admin/users/{userId}/qrcode` with `Accept: application/json`
- **THEN** the server returns `qrPayload` JSON

#### Scenario: PNG QR image
- **WHEN** admin sends `GET /admin/users/{userId}/qrcode` with `Accept: image/png`
- **THEN** the server returns a PNG image encoding the `qrPayload` JSON

### Requirement: Admin status and settings
The server SHALL expose service status and configuration endpoints.

#### Scenario: Service status
- **WHEN** admin sends `GET /admin/status`
- **THEN** the server returns `serverId`, `apiAddr`, `storagePath`, `diskFreeBytes`, and `uptime`

#### Scenario: Update storage path
- **WHEN** admin sends `PUT /admin/settings` with `{ "storagePath": "/new/path" }`
- **THEN** the server updates `config.json` and returns the new path

### Requirement: Recent uploads view
The server SHALL expose recent upload history for the admin dashboard.

#### Scenario: Recent uploads list
- **WHEN** admin sends `GET /admin/uploads/recent?limit=50`
- **THEN** the server returns up to 50 recent upload records from metadata database
