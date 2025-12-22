// Background script for handling downloads

let selectedFolder = null;
let selectedFolderName = null;

// Load selected folder on startup
async function loadSelectedFolder() {
  const result = await browser.storage.local.get(['selectedFolder', 'selectedFolderName']);
  selectedFolder = result.selectedFolder;
  selectedFolderName = result.selectedFolderName;
}

// Listen for messages from popup
browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'setDownloadFolder') {
    selectedFolder = message.folder;
    selectedFolderName = message.folderName;
    console.log(`Download folder set to: ${selectedFolder}`);
    return Promise.resolve({ success: true });
  }
});

// Intercept downloads and modify the save path
browser.downloads.onDeterminingFilename.addListener((downloadItem, suggest) => {
  if (selectedFolder) {
    // Construct the new path with the selected folder
    const filename = downloadItem.filename.split('/').pop();
    const newPath = `${selectedFolder}/${filename}`;

    console.log(`Redirecting download to: ${newPath}`);

    suggest({
      filename: newPath,
      conflictAction: 'uniquify'
    });

    // Show notification
    browser.notifications.create({
      type: 'basic',
      iconUrl: 'icons/icon-48.png',
      title: 'Download Saved',
      message: `File saved to ${selectedFolderName || selectedFolder}`
    });
  } else {
    // No preset folder selected, use default behavior
    suggest({
      filename: downloadItem.filename,
      conflictAction: 'uniquify'
    });
  }

  return true;
});

// Update badge to show active folder
async function updateBadge() {
  if (selectedFolderName) {
    await browser.action.setBadgeText({ text: '✓' });
    await browser.action.setBadgeBackgroundColor({ color: '#34C759' });
    await browser.action.setTitle({
      title: `Preset Folder Downloader - Active: ${selectedFolderName}`
    });
  } else {
    await browser.action.setBadgeText({ text: '' });
    await browser.action.setTitle({ title: 'Preset Folder Downloader' });
  }
}

// Listen for storage changes to update badge
browser.storage.onChanged.addListener((changes, areaName) => {
  if (areaName === 'local' && (changes.selectedFolder || changes.selectedFolderName)) {
    if (changes.selectedFolder) {
      selectedFolder = changes.selectedFolder.newValue;
    }
    if (changes.selectedFolderName) {
      selectedFolderName = changes.selectedFolderName.newValue;
    }
    updateBadge();
  }
});

// Initialize
loadSelectedFolder().then(() => {
  updateBadge();
});

console.log('Preset Folder Downloader extension loaded');
