-- research_term.applescript
-- Asks for a term, researches it via Wikipedia API,
-- and saves a Markdown file to ~/Documents/TermResearch/

-- 1. Ask for a term
set termInput to text returned of (display dialog "Enter a term to research:" default answer "" with title "Term Research" buttons {"Cancel", "Research"} default button "Research")

if termInput is "" then
	display alert "No term entered. Exiting." as warning
	return
end if

-- 2. Prepare the output folder
set outputFolder to (path to documents folder as text) & "TermResearch:"
tell application "Finder"
	if not (exists folder outputFolder) then
		make new folder at (path to documents folder) with properties {name:"TermResearch"}
	end if
end tell

-- 3. URL-encode the term for use in the API call
set encodedTerm to do shell script "python3 -c \"import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))\" " & quoted form of termInput

-- 4. Query the Wikipedia REST API for a summary
set apiURL to "https://en.wikipedia.org/api/rest_v1/page/summary/" & encodedTerm

set jsonResult to do shell script "curl -s --max-time 15 -A 'TermResearch/1.0' " & quoted form of apiURL

-- 5. Parse key fields from the JSON using Python
set parseScript to "
import json, sys
data = json.loads(sys.stdin.read())
title       = data.get('title', 'Unknown')
description = data.get('description', '')
extract     = data.get('extract', 'No description found.')
page_url    = data.get('content_urls', {}).get('desktop', {}).get('page', '')
print(title + '|||' + description + '|||' + extract + '|||' + page_url)
"

set parsedLine to do shell script "echo " & quoted form of jsonResult & " | python3 -c " & quoted form of parseScript

-- Split on the delimiter
set AppleScript's text item delimiters to "|||"
set parsedParts to text items of parsedLine
set AppleScript's text item delimiters to ""

set wikiTitle to item 1 of parsedParts
set wikiDescription to item 2 of parsedParts
set wikiExtract to item 3 of parsedParts
set wikiURL to item 4 of parsedParts

-- 6. Build the Markdown content
set today to do shell script "date '+%Y-%m-%d'"

set mdContent to "# " & wikiTitle & "

**Description:** " & wikiDescription & "

## Summary

" & wikiExtract & "

---

**Source:** [Wikipedia](" & wikiURL & ")
**Researched on:** " & today & "
"

-- 7. Sanitise the filename (replace spaces and slashes with underscores)
set safeFilename to do shell script "echo " & quoted form of termInput & " | tr ' /' '__'"
set outputFilePOSIX to (POSIX path of (path to documents folder)) & "TermResearch/" & safeFilename & ".md"

-- 8. Write the file using Python to handle special characters safely
do shell script "python3 -c \"import sys; open(sys.argv[1], 'w').write(sys.argv[2])\" " & quoted form of outputFilePOSIX & " " & quoted form of mdContent

-- 9. Confirm to the user
display dialog "Research saved!" & return & return & outputFilePOSIX buttons {"Open File", "OK"} default button "OK" with title "Done"
if button returned of result is "Open File" then
	do shell script "open " & quoted form of outputFilePOSIX
end if
