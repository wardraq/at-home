## ADDED Requirements

### Requirement: Synced photo persistence
The app SHALL persist synced photos in SQLite with columns `localIdentifier`, `modificationDate`, and `syncedAt`.

#### Scenario: Record after successful upload
- **WHEN** a photo resource uploads successfully
- **THEN** the app upserts a row with the asset's `localIdentifier` and current `modificationDate`

#### Scenario: Archived records retained
- **WHEN** a photo is deleted from the phone library
- **THEN** the app SHALL NOT delete the corresponding sync record

### Requirement: Incremental sync detection
The app SHALL determine upload need by comparing PhotoKit assets against the sync store.

#### Scenario: New photo
- **WHEN** a `localIdentifier` is not in the sync store
- **THEN** the photo is marked for upload

#### Scenario: Edited photo
- **WHEN** a `localIdentifier` exists but `modificationDate` differs from the stored value
- **THEN** the photo is marked for upload

#### Scenario: Already synced
- **WHEN** `localIdentifier` and `modificationDate` both match the stored record
- **THEN** the photo is skipped

### Requirement: Sync statistics
The app SHALL compute sync statistics using set operations.

#### Scenario: Statistics display
- **WHEN** the home screen loads
- **THEN** the app shows phone count, synced count, pending count, and archived count where:
  - pending = photos in library not synced or with changed modificationDate
  - synced = photos in library with matching sync records
  - archived = sync records not in current library

### Requirement: Clear sync records
The app SHALL allow the user to clear all sync records after confirmation.

#### Scenario: Clear with warning
- **WHEN** user confirms clear sync records
- **THEN** all rows in the sync store are deleted and the app warns that a full re-upload may take significant time and bandwidth
