## ADDED Requirements

### Requirement: Configuration persistence
The server SHALL persist basic configuration in `config.json` separate from sessions and upload metadata.

#### Scenario: First startup
- **WHEN** the server starts without an existing `config.json`
- **THEN** it generates a unique `serverId` with prefix `srv-` and writes default config including `apiPort: 6060`, `adminPort: 6061`, and empty `users` array

#### Scenario: Config contents
- **WHEN** config is loaded
- **THEN** it contains `serverId`, `storagePath`, `apiPort`, `adminPort`, and `users` array with `id`, `name`, `status`, and `createdAt` per user; it MUST NOT contain session tokens or upload records

### Requirement: Session token storage
The server SHALL store session tokens in a dedicated sessions store (memory with disk persistence), isolated from `config.json`.

#### Scenario: Token issuance
- **WHEN** handshake succeeds
- **THEN** a session record is created with `token` (prefix `st-`), `userId`, `deviceName`, `createdAt`, and `expiresAt` (7 days after creation)

#### Scenario: Token validation
- **WHEN** an upload request includes a valid non-expired token for an active user
- **THEN** the request is authorized

#### Scenario: Token revocation on user revoke
- **WHEN** a user is revoked via admin
- **THEN** all session tokens for that `userId` are immediately removed

#### Scenario: Multiple devices
- **WHEN** the same `userId` handshakes from multiple devices
- **THEN** multiple valid session tokens MAY coexist

### Requirement: Metadata database
The server SHALL persist upload metadata in SQLite (`metadata.db`) with `assets` and `uploads` tables.

#### Scenario: Asset record on first upload
- **WHEN** a new `localIdentifier` is uploaded
- **THEN** an `assets` row is created with `user_id`, `local_identifier`, `current_version`, `current_modification_date`, `creation_date`, and `updated_at`

#### Scenario: Upload record per file
- **WHEN** a file is successfully stored
- **THEN** an `uploads` row is created with `user_id`, `local_identifier`, `version`, `part`, `modification_date`, `file_path`, `file_size`, and `uploaded_at`

#### Scenario: Unique constraints
- **WHEN** metadata is written
- **THEN** `assets` enforces uniqueness on `(user_id, local_identifier)` and `uploads` enforces uniqueness on `(user_id, local_identifier, version, part)`

### Requirement: User ID generation
The server SHALL generate user IDs with prefix `usr-` as cryptographically random 128-bit identifiers.

#### Scenario: New user creation
- **WHEN** admin creates a user with name `wardraq`
- **THEN** the server generates a unique `usr-` prefixed ID and sets `name` as immutable storage directory name

### Requirement: Data directory layout
The server SHALL store runtime data alongside the application or in a configurable data directory.

#### Scenario: Runtime files
- **WHEN** the server runs
- **THEN** it maintains `config.json`, sessions persistence file, `metadata.db`, and photo files under `storagePath` independently
