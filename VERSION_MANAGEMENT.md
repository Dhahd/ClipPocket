# Version Management

ClipPocket uses a centralized version management system to ensure consistency across the entire application.

## How It Works

The version number is defined in **one place only**: the Xcode project settings (`MARKETING_VERSION`).

### Single Source of Truth

- **Xcode Project**: `MARKETING_VERSION = 2.0.0` in `ClipPocket.xcodeproj/project.pbxproj`
- This gets written to `Info.plist` as `CFBundleShortVersionString`
- All code reads from this value using the `AppVersion` helper

### AppVersion Helper

The `AppVersion.swift` utility provides centralized access to version information:

```swift
import Foundation

struct AppVersion {
    /// Current version (e.g., "2.0.0")
    static var current: String
    
    /// Build number (e.g., "2")
    static var build: String
    
    /// Full version string (e.g., "2.0.0 (2)")
    static var fullVersion: String
}
```

### Usage Throughout the App

All components now reference `AppVersion.current`:

1. **UpdateChecker.swift** - Uses `AppVersion.current` for update comparison
2. **SettingsView.swift** - Displays `AppVersion.current` in the About section
3. **README.md** - Documents the current stable version (manually updated)

## How to Update the Version

To release a new version:

1. Open the project in Xcode
2. Select the project in the navigator
3. Select the ClipPocket target
4. Go to the "General" tab
5. Update the "Version" field under "Identity"
6. Update the "Build" field if needed
7. Rebuild the app

**OR** edit directly in `ClipPocket.xcodeproj/project.pbxproj`:
```bash
# Update all MARKETING_VERSION entries
sed -i '' 's/MARKETING_VERSION = 2.0.0;/MARKETING_VERSION = 3.0.0;/g' ClipPocket.xcodeproj/project.pbxproj
```

## Files That Reference Version

### Automatic (reads from AppVersion)
- `ClipPocket/Utilities/UpdateChecker.swift`
- `ClipPocket/Views/SettingsView.swift`

### Manual (update as needed)
- `README.md` (line 66)
- `ClipPocket.xcodeproj/project.pbxproj` (MARKETING_VERSION)

## Benefits

✅ **Single source of truth** - Version defined once in Xcode project settings  
✅ **No hardcoded versions** - All code reads from Bundle dynamically  
✅ **Consistent across app** - UpdateChecker, Settings, and About all show the same version  
✅ **Easy to update** - Change in one place, updates everywhere  
✅ **Type-safe** - Swift compiler ensures proper usage

## Current Version

**Version:** 2.0.0  
**Build:** 2
