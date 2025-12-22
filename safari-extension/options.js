// Default folder configurations
const DEFAULT_FOLDERS = {
  folder1: { name: 'Documents', path: 'Documents' },
  folder2: { name: 'Downloads', path: 'Downloads' },
  folder3: { name: 'Desktop', path: 'Desktop' }
};

// Show status message
function showStatus(message, type = 'success') {
  const statusEl = document.getElementById('status');
  statusEl.textContent = message;
  statusEl.className = `status show ${type}`;

  setTimeout(() => {
    statusEl.classList.remove('show');
  }, 3000);
}

// Load settings from storage
async function loadSettings() {
  const result = await browser.storage.local.get(DEFAULT_FOLDERS);

  document.getElementById('folder1Name').value = result.folder1.name;
  document.getElementById('folder1Path').value = result.folder1.path;
  document.getElementById('folder2Name').value = result.folder2.name;
  document.getElementById('folder2Path').value = result.folder2.path;
  document.getElementById('folder3Name').value = result.folder3.name;
  document.getElementById('folder3Path').value = result.folder3.path;
}

// Save settings to storage
async function saveSettings(e) {
  e.preventDefault();

  const settings = {
    folder1: {
      name: document.getElementById('folder1Name').value.trim(),
      path: document.getElementById('folder1Path').value.trim()
    },
    folder2: {
      name: document.getElementById('folder2Name').value.trim(),
      path: document.getElementById('folder2Path').value.trim()
    },
    folder3: {
      name: document.getElementById('folder3Name').value.trim(),
      path: document.getElementById('folder3Path').value.trim()
    }
  };

  // Validate that all fields are filled
  const allFilled = Object.values(settings).every(
    folder => folder.name && folder.path
  );

  if (!allFilled) {
    showStatus('Please fill in all fields', 'error');
    return;
  }

  try {
    await browser.storage.local.set(settings);
    showStatus('Settings saved successfully!', 'success');
  } catch (error) {
    console.error('Error saving settings:', error);
    showStatus('Error saving settings', 'error');
  }
}

// Reset to default settings
async function resetSettings() {
  if (confirm('Are you sure you want to reset to default settings?')) {
    try {
      await browser.storage.local.set(DEFAULT_FOLDERS);
      await loadSettings();
      showStatus('Settings reset to defaults', 'success');
    } catch (error) {
      console.error('Error resetting settings:', error);
      showStatus('Error resetting settings', 'error');
    }
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  loadSettings();

  document.getElementById('settingsForm').addEventListener('submit', saveSettings);
  document.getElementById('resetBtn').addEventListener('click', resetSettings);
});
