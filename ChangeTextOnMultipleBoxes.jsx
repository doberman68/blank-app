// Adobe Illustrator Script: Change Text on Multiple Text Boxes
// This script changes the text content of all selected text frames

(function() {
    // Check if there's an active document
    if (app.documents.length === 0) {
        alert("Please open a document first.");
        return;
    }

    var doc = app.activeDocument;
    var selection = doc.selection;

    // Check if anything is selected
    if (selection.length === 0) {
        alert("Please select at least one text box.");
        return;
    }

    // Filter selection to get only text frames
    var textFrames = [];
    for (var i = 0; i < selection.length; i++) {
        if (selection[i].typename === "TextFrame") {
            textFrames.push(selection[i]);
        }
    }

    // Check if any text frames were selected
    if (textFrames.length === 0) {
        alert("No text boxes found in selection. Please select at least one text box.");
        return;
    }

    // Prompt user for new text
    var newText = prompt("Enter the new text for the selected text boxes:", "");

    // Check if user cancelled or entered empty text
    if (newText === null) {
        return; // User cancelled
    }

    // Update all selected text frames
    var updatedCount = 0;
    for (var j = 0; j < textFrames.length; j++) {
        try {
            textFrames[j].contents = newText;
            updatedCount++;
        } catch (e) {
            // Continue with other text frames if one fails
        }
    }

    // Show confirmation
    if (updatedCount > 0) {
        alert("Successfully updated " + updatedCount + " text box" + (updatedCount > 1 ? "es" : "") + ".");
    } else {
        alert("No text boxes were updated.");
    }
})();
