## ADDED Requirements

### Requirement: Manual sync trigger
The app SHALL sync photos only when the user explicitly taps a sync button in Phase 1.

#### Scenario: Start manual sync
- **WHEN** user taps "Sync Now" on the home screen
- **THEN** the sync engine runs ping → handshake → queue build → sequential upload

#### Scenario: Sync already running
- **WHEN** user taps sync while a sync is in progress
- **THEN** the app ignores the duplicate request or shows already syncing

### Requirement: Upload ordering
The app SHALL upload pending photos from oldest to newest by `creationDate`.

#### Scenario: Chronological upload
- **WHEN** multiple photos are pending
- **THEN** the engine uploads them in ascending `creationDate` order

### Requirement: Foreground upload queue
The app SHALL perform uploads sequentially in the foreground using URLSession.

#### Scenario: Progress reporting
- **WHEN** sync is in progress
- **THEN** the UI shows current progress as completed count over total pending count

### Requirement: Per-resource success tracking
The app SHALL update the sync store only after each resource upload succeeds.

#### Scenario: Live Photo partial completion
- **WHEN** image uploads succeed but video fails
- **THEN** the sync record is not updated until both parts succeed, or the engine retries the failed part

### Requirement: Error handling and retry
The app SHALL continue the queue after a single photo failure and report failures at the end.

#### Scenario: Single upload failure
- **WHEN** one photo upload fails with a network error
- **THEN** the engine logs the failure, continues with remaining photos, and shows a summary when done

#### Scenario: Session re-handshake
- **WHEN** upload fails with token expired
- **THEN** the engine re-handshakes and retries the failed upload once

### Requirement: Server version not tracked
The app SHALL NOT store or send version numbers; the server assigns versions based on `modificationDate`.

#### Scenario: Re-sync after clear
- **WHEN** user clears sync records and re-uploads photos with unchanged modification dates
- **THEN** the server handles uploads idempotently without creating duplicate versions
