## ADDED Requirements

### Requirement: QR code pairing
The app SHALL scan a QR code containing JSON with `serverId`, `userId`, and `addr`, and persist all three fields securely.

#### Scenario: Successful scan
- **WHEN** user scans a valid AtHome pairing QR code
- **THEN** the app stores `serverId`, `userId`, and `addr` in Keychain and transitions to the paired state

#### Scenario: Invalid QR payload
- **WHEN** user scans a QR code missing required fields
- **THEN** the app shows an error and remains in the unpaired state

### Requirement: Connection test
The app SHALL provide a test-connection action that verifies reachability and server identity.

#### Scenario: Successful connection test
- **WHEN** user taps test connection after pairing
- **THEN** the app sends `GET /ping`, performs `POST /handshake`, and verifies the response `serverId` matches the stored value

#### Scenario: Server identity mismatch
- **WHEN** handshake response `serverId` does not match the stored `serverId`
- **THEN** the app reports a possible wrong server and does not save the session token

### Requirement: Secure credential storage
The app SHALL store pairing credentials and session tokens in Keychain, not UserDefaults.

#### Scenario: Token persistence across launches
- **WHEN** the app restarts with a valid unexpired session token in Keychain
- **THEN** the app MAY reuse the token without re-handshake until expiry or 401
