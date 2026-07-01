## ADDED Requirements

### Requirement: Unpaired screen
The app SHALL show a dedicated screen when no pairing credentials exist.

#### Scenario: First launch
- **WHEN** the app launches without Keychain pairing data
- **THEN** the user sees QR scan and test-connection options

### Requirement: Home screen
The app SHALL show sync statistics and a manual sync button when paired.

#### Scenario: Home dashboard
- **WHEN** user is paired and opens the home screen
- **THEN** the screen displays phone photo count, synced count, pending count, archived count, last sync time, and sync progress during active sync

### Requirement: Settings screen
The app SHALL provide settings for sync management.

#### Scenario: Clear sync records UI
- **WHEN** user opens settings and taps clear sync records
- **THEN** the app shows a confirmation dialog warning about time and bandwidth before deleting records

#### Scenario: Pairing info display
- **WHEN** user opens settings while paired
- **THEN** the screen shows server address, user name, and option to re-scan QR

### Requirement: No photo browser
The app SHALL NOT include photo browsing or editing features in MVP.

#### Scenario: Feature scope
- **WHEN** user navigates the app
- **THEN** there is no photo gallery or viewer screen
