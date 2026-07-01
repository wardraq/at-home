## ADDED Requirements

### Requirement: Ping endpoint for reachability
The server SHALL expose `GET /ping` on port 6060 bound to `0.0.0.0` without authentication.

#### Scenario: Successful ping
- **WHEN** a client sends `GET /ping`
- **THEN** the server responds with HTTP 200 and JSON containing `status: "ok"`, `serverId`, and `version`

### Requirement: Handshake authentication
The server SHALL expose `POST /handshake` on port 6060 to validate `userId` and issue a `sessionToken`.

#### Scenario: Successful handshake
- **WHEN** a client sends valid JSON with `userId` and `deviceName` for an active user
- **THEN** the server responds with HTTP 200 and JSON containing `status: "ok"`, `serverId`, `sessionToken`, `userName`, and `expiresAt` (7 days from issuance)

#### Scenario: Unknown user
- **WHEN** a client sends a `userId` not in the user list
- **THEN** the server responds with HTTP 401 and error code `USER_NOT_FOUND`

#### Scenario: Revoked user
- **WHEN** a client sends a `userId` with status `revoked`
- **THEN** the server responds with HTTP 403 and error code `USER_REVOKED`

### Requirement: Photo upload with session token
The server SHALL expose `POST /upload` on port 6060 requiring `Authorization: Bearer <sessionToken>`.

#### Scenario: Successful upload
- **WHEN** a client sends multipart form with `file`, `localIdentifier`, `modificationDate`, `creationDate`, and `part` (`image` or `video`) using a valid session token
- **THEN** the server stores the file, writes metadata, responds with HTTP 200 including assigned `version`, `path`, and `uploadedAt`

#### Scenario: Invalid or expired token
- **WHEN** a client sends upload without a valid session token
- **THEN** the server responds with HTTP 401 and error code `INVALID_TOKEN` or `TOKEN_EXPIRED`

#### Scenario: Modification date regression
- **WHEN** a client uploads with `modificationDate` earlier than the stored `current_modification_date` for the same `localIdentifier`
- **THEN** the server responds with HTTP 409 and error code `MODIFICATION_REGRESSION`

### Requirement: Server-side version assignment
The server SHALL assign version numbers based on `modificationDate` changes; clients MUST NOT send `version`.

#### Scenario: First upload for asset
- **WHEN** a client uploads a new `localIdentifier`
- **THEN** the server assigns `version` 1

#### Scenario: Edit with new modification date
- **WHEN** a client uploads an existing `localIdentifier` with a newer `modificationDate`
- **THEN** the server increments `version`, retains previous version files on disk, and updates `current_version`

#### Scenario: Idempotent re-upload
- **WHEN** a client uploads with the same `localIdentifier` and same `modificationDate` as the current record
- **THEN** the server reuses the current `version` without incrementing; same `part` overwrites the file at the same path

#### Scenario: Live Photo two-part upload
- **WHEN** a client uploads `part=image` then `part=video` with the same `localIdentifier` and `modificationDate`
- **THEN** the server assigns the same `version` to both parts

### Requirement: File naming and storage layout
The server SHALL store files under `{storagePath}/{userName}/{YYYY}/{MM}/` using sanitized `localIdentifier` in filenames.

#### Scenario: Filename sanitization
- **WHEN** storing a file for `localIdentifier` `A1B2C3D4-E5F6-7890-ABCD-EF1234567890/L0/001`
- **THEN** the filename uses `A1B2C3D4-E5F6-7890-ABCD-EF1234567890_L0_001_v{version}_{part}.{ext}`

#### Scenario: Directory from creation date
- **WHEN** a client uploads with `creationDate` `2025-07-15T10:00:00+08:00`
- **THEN** the file is stored under `{userName}/2025/07/`
