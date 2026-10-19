# Commonplace iOS App

A native SwiftUI iPhone app for your commonplace journal.

## Setup Instructions

### Step 1: Prepare Your Xcode Project

You already have a fresh Xcode project called "commonplace" that runs on your iPhone. Follow these steps:

1. **Open your project** in Xcode 26
2. **Delete the template files** — In the Project Navigator (left sidebar), right-click and delete:
   - `MyApp.swift` (or whatever your main `@main` file is called)
   - `ContentView.swift`
   - Choose "Move to Trash" when prompted

### Step 2: Add the Commonplace Files

1. **Open Finder** and navigate to the `ios/Commonplace/` folder from this repository
2. **Select all the `.swift` files**:
   - `MyApp.swift`
   - `ContentView.swift`
   - `Entry.swift`
   - `EntryStore.swift`
   - `JournalView.swift`
   - `EntryCardView.swift`
   - `EntryEditorView.swift`
   - `SearchView.swift`
   - `PullOneView.swift`
   - `SettingsView.swift`
3. **Drag them into your Xcode project** (drop them on your project folder in the navigator)
4. In the dialog that appears:
   - ✅ Check **"Copy items if needed"**
   - ✅ Check **"Create groups"**
   - ✅ Make sure your app target is checked under "Add to targets"
   - Click **Add**

### Step 3: Rename the Main Struct (if needed)

If your original `@main` struct was not named `MyApp`, open the new `MyApp.swift` and rename the struct to match your original name. For example, if your template file had:

```swift
@main
struct commonplaceApp: App {
```

Then change `MyApp` to `commonplaceApp` in the new file.

### Step 4: Build and Run

1. Select your iPhone as the run destination
2. Press **⌘R** (or click the Play button) to build and run
3. If you see any red errors, check:
   - Make sure you deleted both original template files
   - Make sure all 10 Swift files are added to the target

## Moving Your Entries from the Web App

Already have entries in the web PWA? Here's how to bring them over:

### Export from Web

1. Open the Commonplace web app (Safari, Chrome, or as an installed PWA)
2. Go to **Settings** (bottom tab bar)
3. Tap **Export**
4. Save the `.json` file — either:
   - **AirDrop** it to your iPhone
   - **Save to Files** (iCloud Drive or On My iPhone)

### Import into the iOS App

1. Open the Commonplace iOS app
2. Go to **Settings** (bottom tab bar)  
3. Tap **Import JSON**
4. Navigate to where you saved the export file and select it
5. You'll see a confirmation: "X new, Y updated"

Your entries are now on both devices! The import merges by entry ID, and newer edits win if you have the same entry on both.

## Features

- **Journal**: Browse entries grouped by day, filter by type or tag
- **Search**: Find entries by text, author, or #tags
- **Pull one**: Random entry with smart weighting (quotes and favorites appear more often)
- **Settings**: Stats, export, import, and erase all

## Data Storage

All entries are stored locally in a JSON file in your app's Documents folder. There's no cloud sync, no accounts, no servers — your data stays on your device.

## Troubleshooting

### "Cannot find 'EntryStore' in scope" or similar errors
Make sure all 10 Swift files are added to your target:
1. Select any `.swift` file in the navigator
2. In the File Inspector (right sidebar), under "Target Membership"
3. Make sure your app target is checked

### App crashes on launch
Check that you only have ONE file with `@main struct` — delete any duplicate app entry points.

### Import doesn't work
Make sure the JSON file is a valid Commonplace export. The app accepts:
- The standard export format: `{ "app": "Commonplace", "version": 1, "entries": [...] }`
- Or a plain array of entries: `[{ "id": "...", "type": "quote", ... }]`

## Requirements

- iOS 17.0 or later
- Xcode 26 (or Xcode 15+)
- No external dependencies
