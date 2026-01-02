# SledLink Release Process

This document describes how to create a new release of SledLink.

## Prerequisites

- Write access to the SledLink repository
- Git installed locally
- Commits ready to release on the main branch

## Release Steps

### 1. Decide Version Number

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (v4.0.0): Breaking changes, incompatible API changes
- **MINOR** (v3.1.0): New features, backward compatible
- **PATCH** (v3.0.1): Bug fixes, backward compatible

Current firmware displays "v3.0" - this is independent of release version.

### 2. Create and Push Tag

```bash
# Ensure you're on main branch and up to date
git checkout main
git pull

# Create annotated tag
git tag -a v3.0.1 -m "Release v3.0.1: Bug fixes and improvements"

# Push tag to GitHub
git push origin v3.0.1
```

### 3. Monitor GitHub Actions

1. Go to: https://github.com/thompcd/SledLink/actions
2. Watch the "Build and Release" workflow
3. It will:
   - Validate the tag
   - Install dependencies
   - Compile both firmwares
   - Create release package
   - Create GitHub release
   - Upload ZIP file

### 4. Verify Release

1. Go to: https://github.com/thompcd/SledLink/releases
2. Check that your release appears with:
   - Correct version number
   - ZIP file attached
   - Generated changelog
   - Installation instructions

### 5. Edit Release Notes (Optional)

You can enhance the auto-generated release notes:

1. Click "Edit" on the release
2. Add highlights, known issues, or additional context
3. Save

## Pre-Release Versions

For beta or RC versions, add a suffix:

```bash
git tag -a v3.1.0-beta.1 -m "Beta release for testing"
git push origin v3.1.0-beta.1
```

GitHub will automatically mark these as "Pre-release".

## Troubleshooting

### Build Failed

1. Check the Actions log for the error
2. Common issues:
   - Syntax error in code
   - Missing library dependency
   - Build script issue
3. Fix the issue, create a new tag (v3.0.2)

### Wrong Version Released

1. Delete the tag locally: `git tag -d v3.0.1`
2. Delete the tag remotely: `git push --delete origin v3.0.1`
3. Delete the GitHub release (manually on GitHub)
4. Create correct tag

### Manual Release (Emergency)

If GitHub Actions is down:

```bash
# Run build script locally
./build_release.sh v3.0.1

# Create release manually on GitHub
# Upload release/SledLink-v3.0.1.zip
```

## Maintainer Workflow Example

### Scenario: Bug Fix Release

```bash
# Developer finds and fixes encoder bug
git checkout -b fix/encoder-bug
# ... make changes ...
git commit -m "Fix encoder overflow on long pulls"
git push origin fix/encoder-bug

# Create PR, get review, merge to main

# Maintainer creates release
git checkout main
git pull
git tag -a v3.0.1 -m "Release v3.0.1: Fix encoder overflow"
git push origin v3.0.1

# GitHub Actions automatically:
# - Builds firmware
# - Creates release
# - Uploads ZIP
# - Generates changelog

# Maintainer verifies on GitHub Releases page
# Users download SledLink-v3.0.1.zip
```

### Scenario: New Feature Release

```bash
# Developer adds WiFi config UI
git checkout -b feature/wifi-config
# ... make changes ...
git commit -m "Add WiFi configuration web UI"
git push origin feature/wifi-config

# Create PR, get review, merge to main

# Update firmware display version if major change
# Edit arduino/*/Controller.ino: #define FIRMWARE_DISPLAY_VERSION "v3.1"

# Maintainer creates release
git checkout main
git pull
git tag -a v3.1.0 -m "Release v3.1.0: WiFi configuration UI"
git push origin v3.1.0

# GitHub Actions builds and releases
```

## Version History

| Version | Date | Notes |
|---------|------|-------|
| v1.0.0 | TBD | First public release |
