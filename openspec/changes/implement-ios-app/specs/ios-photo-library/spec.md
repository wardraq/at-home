## ADDED Requirements

### Requirement: Photo library read access
The app SHALL request read-only photo library access to enumerate user photos.

#### Scenario: Permission granted
- **WHEN** user grants photo library access
- **THEN** the app can enumerate assets from the user's library

#### Scenario: Permission denied
- **WHEN** user denies photo library access
- **THEN** the app shows an explanation and cannot sync

### Requirement: Local-only assets
The app SHALL only export photos that are locally available on device; it MUST NOT download from iCloud during sync.

#### Scenario: Locally available photo
- **WHEN** a photo's resources are available locally
- **THEN** the app exports and uploads the original resource files

#### Scenario: iCloud-only photo
- **WHEN** a photo is not locally available
- **THEN** the app skips the photo, continues the queue, and counts it as skipped (not failed)

### Requirement: Original resource export
The app SHALL export original asset resources without transcoding to JPEG.

#### Scenario: HEIC still photo
- **WHEN** exporting a still HEIC photo
- **THEN** the app uploads the original image resource with `part=image`

### Requirement: Live Photo export
The app SHALL export Live Photos as two uploads sharing the same `localIdentifier` and `modificationDate`.

#### Scenario: Live Photo upload
- **WHEN** syncing a Live Photo
- **THEN** the app uploads `part=image` for the photo resource and `part=video` for the paired video resource

### Requirement: Library scope
The app SHALL enumerate the user's camera roll / library only, not shared albums, for MVP.

#### Scenario: Camera roll enumeration
- **WHEN** building the upload queue
- **THEN** the app fetches assets from the smart album user library only
