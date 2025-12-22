# Safari Preset Folder Downloader Extension

A Safari Web Extension that allows you to save downloaded files to one of three preset folders with just one click.

## Features

- 🗂️ Configure 3 preset folders for quick file downloads
- 📁 One-click download to your chosen preset folder
- ⚙️ Easy configuration through settings page
- 🔔 Download notifications
- ✨ Clean, modern UI following Apple design guidelines

## Installation

### For Safari on macOS

1. **Enable Safari Developer Mode**
   - Open Safari
   - Go to Safari > Settings (or Preferences)
   - Click on "Advanced"
   - Check "Show Develop menu in menu bar"

2. **Load the Extension**
   - In Safari, go to Develop > Allow Unsigned Extensions
   - Go to Safari > Settings > Extensions
   - Click the "+" button or "Show in Finder" button
   - Navigate to the `safari-extension` folder and select it
   - Enable the "Preset Folder Downloader" extension

### Alternative: Convert to Safari App Extension

For distribution through the App Store or for a more permanent installation:

1. Open Xcode
2. Create a new Safari Extension App project
3. Copy all files from this `safari-extension` folder into the extension target
4. Build and run the project

## Usage

### Initial Setup

1. Click the extension icon in Safari's toolbar
2. Click "⚙️ Configure Folders"
3. Set up your three preset folders:
   - Enter a name for each folder (e.g., "Work Documents")
   - Enter the path relative to your Downloads folder (e.g., "Work/Documents")
4. Click "Save Settings"

### Downloading Files

1. When you want to download a file, click the extension icon
2. Select one of your three preset folders
3. The next file you download will be saved to that folder automatically
4. You'll see a notification confirming the save location

### Changing Download Location

Simply click the extension icon again and select a different preset folder. The extension will remember your selection for future downloads.

## Configuration

### Folder Paths

- Paths are relative to your default Downloads folder
- Use forward slashes (/) for subfolders
- Examples:
  - `Documents` → Downloads/Documents
  - `Work/Projects` → Downloads/Work/Projects
  - `Media/Videos` → Downloads/Media/Videos
- Folders will be created automatically if they don't exist

### Default Folders

The extension comes with three default preset folders:
1. Documents (~/Documents)
2. Downloads (~/Downloads)
3. Desktop (~/Desktop)

You can customize these in the settings page.

## Development

### File Structure

```
safari-extension/
├── manifest.json          # Extension configuration
├── background.js          # Background service worker
├── popup.html            # Main popup UI
├── popup.css             # Popup styles
├── popup.js              # Popup logic
├── options.html          # Settings page
├── options.css           # Settings styles
├── options.js            # Settings logic
├── icons/                # Extension icons
│   ├── icon-48.png
│   ├── icon-96.png
│   └── icon-128.png
├── create-icons.py       # Icon generator script
└── generate-icons.html   # Browser-based icon generator
```

### Building Icons

If you need to regenerate the icons:

**Option 1: Python Script**
```bash
pip install Pillow
python3 create-icons.py
```

**Option 2: Browser-based**
Open `generate-icons.html` in your browser and download each icon size.

### Permissions

The extension requires the following permissions:
- `downloads`: To intercept and modify download paths
- `storage`: To save your preset folder configurations

## Browser Compatibility

This extension is built for Safari but uses the WebExtensions API (Manifest V3), making it compatible with:
- Safari 14+ (macOS)
- Chrome/Edge (with minimal modifications)
- Firefox (with minimal modifications)

## Troubleshooting

### Extension doesn't appear in Safari
- Make sure you've enabled "Show Develop menu in menu bar" in Safari Settings > Advanced
- Enable "Allow Unsigned Extensions" in the Develop menu
- Check that the extension is enabled in Safari Settings > Extensions

### Downloads not saving to preset folders
- Check that you've selected a preset folder by clicking the extension icon
- Verify your folder paths in the settings page
- Make sure Safari has permission to access your file system

### Folders not being created
- Ensure the paths don't start with `/` or `~`
- Use only alphanumeric characters, hyphens, and underscores in folder names
- Check that you have write permissions in your Downloads folder

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.
