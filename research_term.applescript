-- research_term.applescript
-- Asks for a term, researches it via OpenAI API,
-- and saves a Markdown file to ~/Documents/TermResearch/

-- 1. Ask for a term
set termInput to text returned of (display dialog "Enter a term to research:" default answer "" with title "Term Research" buttons {"Cancel", "Research"} default button "Research")

if termInput is "" then
	display alert "No term entered. Exiting." as warning
	return
end if

-- 2. Ask for the OpenAI API key (or read from env / a dotfile)
set apiKey to ""

-- Try reading from ~/.openai_api_key first so the user isn't prompted every run
try
	set apiKey to do shell script "cat ~/.openai_api_key 2>/dev/null | tr -d '\\n'"
end try

if apiKey is "" then
	set apiKey to text returned of (display dialog "Enter your OpenAI API key:" default answer "" with title "OpenAI API Key" buttons {"Cancel", "Continue"} default button "Continue" with hidden answer)
end if

if apiKey is "" then
	display alert "No API key provided. Exiting." as warning
	return
end if

-- 3. Prepare the output folder
set outputFolder to (path to documents folder as text) & "TermResearch:"
tell application "Finder"
	if not (exists folder outputFolder) then
		make new folder at (path to documents folder) with properties {name:"TermResearch"}
	end if
end tell

-- 4. Call the OpenAI Chat Completions API via Python
set pythonScript to "
import sys, json, urllib.request, urllib.error

term    = sys.argv[1]
api_key = sys.argv[2]

prompt = (
    f'Research the term \"{term}\" and provide a thorough explanation. '
    'Structure your response as Markdown with these sections:\\n'
    '## Definition\\n'
    '## Background\\n'
    '## Key Concepts\\n'
    '## Examples\\n'
    '## Further Reading\\n'
    'Be concise but informative.'
)

payload = json.dumps({
    'model': 'gpt-4o',
    'messages': [
        {'role': 'system', 'content': 'You are a knowledgeable research assistant. Respond only in well-structured Markdown.'},
        {'role': 'user',   'content': prompt}
    ],
    'temperature': 0.5
}).encode()

req = urllib.request.Request(
    'https://api.openai.com/v1/chat/completions',
    data=payload,
    headers={
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {api_key}'
    }
)

try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read())
        print(data['choices'][0]['message']['content'])
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print(f'ERROR:{e.code}:{body}', file=sys.stderr)
    sys.exit(1)
"

set apiResponse to do shell script "python3 -c " & quoted form of pythonScript & " " & quoted form of termInput & " " & quoted form of apiKey

-- 5. Check for errors
if apiResponse starts with "ERROR:" then
	display alert "OpenAI API error:" & return & apiResponse as critical
	return
end if

-- 6. Build the Markdown file content
set today to do shell script "date '+%Y-%m-%d'"

set mdContent to "# " & termInput & "

" & apiResponse & "

---

**Researched on:** " & today & "
**Source:** OpenAI GPT-4o
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
