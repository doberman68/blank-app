-- Hazel AppleScript: Research Term and Create Markdown
--
-- How to use:
-- 1. In Hazel, create a rule that triggers on file creation
-- 2. Add a "Run AppleScript" action and paste this script
-- 3. Set your ANTHROPIC_API_KEY in the script below (or export it in ~/.zshenv)
-- 4. The file content should contain the term you want researched
-- 5. A markdown file will be created in the same folder as the source file

on hazelProcessFile(theFile)
	-- ── Configuration ────────────────────────────────────────────────────────
	set apiKey to "YOUR_ANTHROPIC_API_KEY" -- replace or leave blank to use env var
	set claudeModel to "claude-opus-4-6"
	-- ─────────────────────────────────────────────────────────────────────────

	set filePath to POSIX path of theFile

	-- Read the term from the file
	set termText to do shell script "cat " & quoted form of filePath

	-- Strip leading/trailing whitespace from the term
	set termText to do shell script "echo " & quoted form of termText & " | xargs"

	if termText is "" then
		return -- nothing to do for empty files
	end if

	-- Build the output markdown file path (same directory, term as filename)
	set safeFilename to do shell script "echo " & quoted form of termText & " | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'"
	set outputDir to do shell script "dirname " & quoted form of filePath
	set outputPath to outputDir & "/" & safeFilename & ".md"

	-- Call Claude API via Python (handles JSON cleanly)
	set pythonScript to "
import subprocess, json, sys, os

api_key = " & quoted form of apiKey & " or os.environ.get('ANTHROPIC_API_KEY', '')
if not api_key:
    sys.exit('ANTHROPIC_API_KEY not set')

term = " & quoted form of termText & "

payload = {
    'model': " & quoted form of claudeModel & ",
    'max_tokens': 4096,
    'thinking': {'type': 'adaptive'},
    'messages': [{
        'role': 'user',
        'content': (
            f'Research the term or concept: **{term}**\\n\\n'
            'Write a thorough explanation suitable for a reference document. '
            'Structure your response as a well-formatted Markdown document with:\\n'
            '- A top-level heading with the term name\\n'
            '- A concise one-paragraph summary\\n'
            '- Key concepts or sub-sections (use ## headings)\\n'
            '- Examples where applicable\\n'
            '- Related terms or see-also references at the end\\n\\n'
            'Output ONLY the Markdown content — no preamble, no code fences around it.'
        )
    }]
}

result = subprocess.run(
    [
        'curl', '-s', '-X', 'POST',
        'https://api.anthropic.com/v1/messages',
        '-H', 'Content-Type: application/json',
        '-H', f'x-api-key: {api_key}',
        '-H', 'anthropic-version: 2023-06-01',
        '-d', json.dumps(payload)
    ],
    capture_output=True, text=True
)

data = json.loads(result.stdout)

if 'error' in data:
    sys.exit(f\"API error: {data['error']['message']}\")

# Extract text blocks (skip thinking blocks)
markdown = '\\n\\n'.join(
    block['text']
    for block in data.get('content', [])
    if block.get('type') == 'text'
)

print(markdown, end='')
"

	set markdownContent to do shell script "python3 -c " & quoted form of pythonScript

	-- Write the markdown file
	do shell script "printf '%s' " & quoted form of markdownContent & " > " & quoted form of outputPath

	-- Notify user
	display notification "Created " & safeFilename & ".md" with title "Hazel Research" subtitle termText

end hazelProcessFile
