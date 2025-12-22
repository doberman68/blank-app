// Load preset folders from storage
async function loadPresetFolders() {
  const result = await browser.storage.local.get({
    folder1: { name: 'Documents', path: 'Documents' },
    folder2: { name: 'Downloads', path: 'Downloads' },
    folder3: { name: 'Desktop', path: 'Desktop' }
  });

  // Update UI with loaded folders
  document.getElementById('folder1Name').textContent = result.folder1.name;
  document.getElementById('folder1Path').textContent = result.folder1.path;
  document.getElementById('folder2Name').textContent = result.folder2.name;
  document.getElementById('folder2Path').textContent = result.folder2.path;
  document.getElementById('folder3Name').textContent = result.folder3.name;
  document.getElementById('folder3Path').textContent = result.folder3.path;

  return result;
}

// Show status message
function showStatus(message, type = 'info') {
  const statusEl = document.getElementById('status');
  statusEl.textContent = message;
  statusEl.className = `status show ${type}`;

  setTimeout(() => {
    statusEl.classList.remove('show');
  }, 3000);
}

// Set the selected folder for the next download
async function setSelectedFolder(folderKey, folderData) {
  try {
    await browser.storage.local.set({
      selectedFolder: folderData.path,
      selectedFolderName: folderData.name
    });

    showStatus(`Downloads will be saved to ${folderData.name}`, 'success');

    // Send message to background script
    await browser.runtime.sendMessage({
      action: 'setDownloadFolder',
      folder: folderData.path,
      folderName: folderData.name
    });
  } catch (error) {
    console.error('Error setting folder:', error);
    showStatus('Error setting folder', 'error');
  }
}

// Initialize popup
async function init() {
  const folders = await loadPresetFolders();

  // Add click handlers to folder items
  document.querySelectorAll('.folder-item').forEach(item => {
    item.addEventListener('click', async () => {
      const folderNum = item.dataset.folder;
      const folderKey = `folder${folderNum}`;
      const folderData = folders[folderKey];

      await setSelectedFolder(folderKey, folderData);
    });
  });

  // Settings button handler
  document.getElementById('settingsBtn').addEventListener('click', () => {
    browser.runtime.openOptionsPage();
  });

  // Check if there's a current selected folder
  const currentSelection = await browser.storage.local.get('selectedFolderName');
  if (currentSelection.selectedFolderName) {
    showStatus(`Current: ${currentSelection.selectedFolderName}`, 'info');
  }
}

// Run initialization
init();
