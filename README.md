# 🔴🟢 Laser Vector Art Generator

A production-ready web application that generates laser-cut and laser-engrave vector artwork using Claude AI. Creates manufacturing-ready SVG files with proper color coding for laser cutting software like LightBurn, Epilog, and Glowforge.

## Features

- **AI-Powered Vector Generation**: Uses Claude 3.5 Sonnet to create custom laser-ready artwork
- **Strict Color Coding**:
  - 🔴 **RED (#FF0000)**: Cut paths (exterior silhouette)
  - 🟢 **GREEN (#00FF00)**: Engrave paths (interior details)
- **Real-Time Validation**: Automatically validates SVG output against laser cutting requirements
- **Production Ready**: Zero manual cleanup required - output goes directly to laser software
- **Download & Export**: Download SVG files or copy code to clipboard
- **Secure**: API keys stored locally in browser storage only

## Design Specifications

The generator creates artwork with:
- Simple, childlike illustration style
- Hand-drawn look with smooth, rounded geometry
- Single continuous red exterior silhouette (cut path)
- Green interior details only (engrave paths)
- No fills, gradients, or shading
- Stroke-based paths only

## Prerequisites

- Node.js (v14 or higher)
- Anthropic API key ([Get one here](https://console.anthropic.com/))

## Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd blank-app
```

2. Install dependencies:
```bash
npm install
```

## Usage

1. Start the server:
```bash
npm start
```

2. Open your browser and navigate to:
```
http://localhost:3000
```

3. Enter your Anthropic API key (stored locally in your browser)

4. Type what you want to create (e.g., "owl", "cat", "tree", "person")

5. Click "Generate Artwork"

6. Review the generated SVG and validation results

7. Download the SVG file or copy the code

## Development

Run the server with auto-reload:
```bash
npm run dev
```

## File Structure

```
blank-app/
├── index.html          # Main application interface
├── styles.css          # Professional UI styling
├── app.js             # Frontend logic and API integration
├── server.js          # Express server for serving static files
├── package.json       # Node dependencies
└── README.md          # This file
```

## API Key Security

Your Anthropic API key is:
- Stored only in your browser's localStorage
- Never sent to our servers
- Used directly from your browser to Anthropic's API
- Can be cleared by deleting browser data

## Laser Software Compatibility

Generated SVG files are compatible with:
- LightBurn
- Epilog Dashboard
- Glowforge App
- RDWorks
- LaserGRBL
- Any software that supports red/green color-coded layers

## Validation Rules

The app automatically validates:
- ✓ Presence of red (#FF0000) cut paths
- ✓ Single continuous red silhouette (ideal)
- ✓ Presence of green (#00FF00) engrave paths
- ✓ Correct color coding (only red and green)
- ✓ Stroke-only design (no fills)

## Troubleshooting

**API Error**: Make sure you've entered a valid Anthropic API key

**Invalid SVG**: Try regenerating or provide a more specific subject description

**Validation Warnings**: Review the validation panel for specific issues

## Examples

Try generating:
- Animals: "owl", "cat", "elephant", "butterfly"
- Nature: "tree", "flower", "leaf", "mountain"
- Objects: "house", "car", "bicycle", "guitar"
- People: "person waving", "dancer", "athlete"

## System Prompt

The app uses a comprehensive system prompt that enforces:
- Laser-ready vector artwork standards
- Strict color coding rules
- Production-safe geometry
- Manufacturing constraints

See `app.js` for the complete system prompt.

## License

MIT

## Support

For issues and questions, please open an issue on GitHub.

---

**Note**: This application requires an active internet connection to communicate with the Anthropic API.
