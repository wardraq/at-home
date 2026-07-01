## ADDED Requirements

### Requirement: Ping endpoint
The network client SHALL call `GET http://{addr}/ping` and parse `serverId` and `status`.

#### Scenario: Server reachable
- **WHEN** the server is reachable on the LAN
- **THEN** the client returns a successful ping response with `serverId`

#### Scenario: Server unreachable
- **WHEN** the server is not reachable
- **THEN** the client returns a network error without crashing

### Requirement: Handshake
The network client SHALL call `POST /handshake` with `userId` and `deviceName`.

#### Scenario: Successful handshake
- **WHEN** handshake succeeds
- **THEN** the client returns `sessionToken`, `serverId`, `userName`, and `expiresAt`

#### Scenario: Token expiry handling
- **WHEN** an upload receives HTTP 401 with `TOKEN_EXPIRED`
- **THEN** the client SHALL automatically re-handshake once and retry the request

### Requirement: Multipart upload
The network client SHALL upload photos via `POST /upload` with `Authorization: Bearer {token}` and multipart fields per api-server.md.

#### Scenario: Static photo upload
- **WHEN** uploading a still image
- **THEN** the client sends `file`, `localIdentifier`, `modificationDate`, `creationDate`, `part=image`, and optional `originalFilename` / `mimeType`; it MUST NOT send `version`

#### Scenario: Modification date format
- **WHEN** sending `modificationDate` or `creationDate`
- **THEN** the client SHALL use a canonical ISO 8601 format with second precision and consistent timezone encoding
