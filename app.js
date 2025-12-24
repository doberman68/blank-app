// DOM Elements
const subjectInput = document.getElementById('subject-input');
const apiKeyInput = document.getElementById('api-key-input');
const generateBtn = document.getElementById('generate-btn');
const downloadBtn = document.getElementById('download-btn');
const copySvgBtn = document.getElementById('copy-svg-btn');
const statusMessage = document.getElementById('status-message');
const previewContainer = document.getElementById('preview-container');
const svgPreview = document.getElementById('svg-preview');
const validationResults = document.getElementById('validation-results');
const validationContent = document.getElementById('validation-content');

// State
let currentSVG = '';
let currentSubject = '';

// Load API key from localStorage
window.addEventListener('DOMContentLoaded', () => {
    const savedApiKey = localStorage.getItem('anthropic_api_key');
    if (savedApiKey) {
        apiKeyInput.value = savedApiKey;
    }
});

// Save API key to localStorage
apiKeyInput.addEventListener('change', () => {
    const apiKey = apiKeyInput.value.trim();
    if (apiKey) {
        localStorage.setItem('anthropic_api_key', apiKey);
    } else {
        localStorage.removeItem('anthropic_api_key');
    }
});

// System prompt for Claude
const SYSTEM_PROMPT = `You are a professional vector illustrator specializing exclusively in laser-cut and laser-engraved artwork for wood and similar materials.

Your output must always be manufacturing-ready and require zero cleanup in laser software such as LightBurn, Epilog, or Glowforge.

## DESIGN REQUIREMENTS (MANDATORY)

### Style & Visual Language
- Simple, naïve, childlike illustration style
- Hand-drawn look with smooth, rounded geometry
- Friendly, minimal facial features where applicable
- No shading, gradients, textures, fills, or backgrounds
- Must resemble a small engraved wooden figurine or ornament

## LASER COLOR CODING (NON-NEGOTIABLE)

### 🔴 RED (#FF0000) -- CUT GEOMETRY ONLY
- Exactly ONE continuous exterior silhouette
- One closed outer contour
- No interior red paths
- No decorative, dangling, or secondary red strokes
- No tails, accents, or partial lines outside the silhouette
- No overlaps, no duplicates, no breaks
- All physically surviving features (ears, antennae, stems, etc.) MUST be integrated into the exterior silhouette

> Red paths define the ONLY material that remains after cutting.

### 🟢 GREEN (#00FF00) -- ENGRAVE GEOMETRY ONLY
- Interior details ONLY
- Must sit entirely within the red cut boundary
- Single-stroke paths only
- No fills
- No overlapping or doubled lines
- No engraving marks outside the cut area

> Any green line outside the red silhouette is INVALID.

## VECTOR & PRODUCTION CONSTRAINTS
- Output must be true vector artwork (SVG-friendly)
- Stroke-based paths only (no raster elements)
- Avoid thin, fragile, or break-prone geometry
- Engrave details must remain legible in wood
- Clear, intentional separation between cut and engrave paths
- Red geometry must NEVER include non-essential strokes

## COMPOSITION RULES
- Centered, front-facing design
- Rounded, simplified proportions
- Balanced silhouette suitable for small laser-cut items
- Ornament-safe geometry (no accidental drop-outs)

## OUTPUT FORMAT RULES
- Produce ONLY the SVG code, nothing else
- Do not include markdown code blocks or explanations
- Start with <svg and end with </svg>
- White background only
- No text, labels, names, or decorative elements
- Do NOT rasterize or flatten

The final output must be immediately usable in laser software with zero manual correction.

### FAILURE CONDITIONS (DO NOT VIOLATE)
- Multiple red contours
- Red decorative strokes
- Green lines outside cut area
- Engraving details not supported by cut geometry
- Shading, fills, or raster elements

Any violation renders the output invalid.`;

// Generate artwork
generateBtn.addEventListener('click', async () => {
    const subject = subjectInput.value.trim();
    const apiKey = apiKeyInput.value.trim();

    if (!subject) {
        showStatus('Please enter what you would like to create.', 'error');
        return;
    }

    if (!apiKey) {
        showStatus('Please enter your Anthropic API key.', 'error');
        return;
    }

    currentSubject = subject;
    setLoading(true);
    showStatus('Generating laser-ready artwork...', 'info');
    previewContainer.style.display = 'none';

    try {
        const svg = await generateSVG(subject, apiKey);
        currentSVG = svg;
        displaySVG(svg);
        validateSVG(svg);
        showStatus('Artwork generated successfully!', 'success');
        previewContainer.style.display = 'block';
    } catch (error) {
        console.error('Generation error:', error);
        showStatus(`Error: ${error.message}`, 'error');
    } finally {
        setLoading(false);
    }
});

// Generate SVG using Claude API
async function generateSVG(subject, apiKey) {
    const userPrompt = `Create a laser-ready vector illustration of: ${subject}

Remember:
- RED (#FF0000) = cut paths (single exterior silhouette only)
- GREEN (#00FF00) = engrave paths (interior details only)
- Output ONLY the SVG code, no explanations or markdown
- Start with <svg and end with </svg>`;

    const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify({
            model: 'claude-3-5-sonnet-20241022',
            max_tokens: 4096,
            system: SYSTEM_PROMPT,
            messages: [
                {
                    role: 'user',
                    content: userPrompt
                }
            ]
        })
    });

    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error?.message || 'API request failed');
    }

    const data = await response.json();
    let svgContent = data.content[0].text.trim();

    // Extract SVG from markdown code blocks if present
    const svgMatch = svgContent.match(/```(?:svg|xml)?\s*([\s\S]*?)```/) ||
                     svgContent.match(/<svg[\s\S]*<\/svg>/);

    if (svgMatch) {
        svgContent = svgMatch[1] || svgMatch[0];
    }

    // Ensure it starts with <svg
    if (!svgContent.trim().startsWith('<svg')) {
        throw new Error('Generated content is not valid SVG');
    }

    return svgContent.trim();
}

// Display SVG
function displaySVG(svg) {
    svgPreview.innerHTML = svg;
}

// Validate SVG against laser requirements
function validateSVG(svgString) {
    const parser = new DOMParser();
    const doc = parser.parseFromString(svgString, 'image/svg+xml');

    const validations = [];

    // Check for parse errors
    const parseError = doc.querySelector('parsererror');
    if (parseError) {
        validations.push({
            status: 'fail',
            message: 'SVG parsing error detected'
        });
        displayValidation(validations);
        return;
    }

    const svg = doc.querySelector('svg');
    if (!svg) {
        validations.push({
            status: 'fail',
            message: 'No SVG element found'
        });
        displayValidation(validations);
        return;
    }

    // Get all paths and shapes
    const allElements = svg.querySelectorAll('path, circle, rect, ellipse, polygon, polyline, line');

    let redElements = [];
    let greenElements = [];
    let otherElements = [];

    allElements.forEach(el => {
        const stroke = el.getAttribute('stroke')?.toLowerCase();
        const fill = el.getAttribute('fill')?.toLowerCase();

        if (stroke === '#ff0000' || stroke === 'red' || stroke === 'rgb(255,0,0)' || stroke === 'rgb(255, 0, 0)') {
            redElements.push(el);
        } else if (stroke === '#00ff00' || stroke === 'lime' || stroke === 'rgb(0,255,0)' || stroke === 'rgb(0, 255, 0)') {
            greenElements.push(el);
        } else if (fill === '#ff0000' || fill === 'red' || fill === 'rgb(255,0,0)' || fill === 'rgb(255, 0, 0)') {
            redElements.push(el);
        } else if (fill === '#00ff00' || fill === 'lime' || fill === 'rgb(0,255,0)' || fill === 'rgb(0, 255, 0)') {
            greenElements.push(el);
        } else {
            // Check if element has any stroke or fill
            if (stroke || fill) {
                otherElements.push(el);
            }
        }
    });

    // Validation 1: Red cut paths exist
    if (redElements.length > 0) {
        validations.push({
            status: 'pass',
            message: `Found ${redElements.length} red cut path(s)`
        });
    } else {
        validations.push({
            status: 'fail',
            message: 'No red (#FF0000) cut paths found'
        });
    }

    // Validation 2: Check for single red contour (ideal)
    if (redElements.length === 1) {
        validations.push({
            status: 'pass',
            message: 'Single red cut contour (ideal)'
        });
    } else if (redElements.length > 1) {
        validations.push({
            status: 'warning',
            message: `Multiple red elements found (${redElements.length}). Should be exactly one continuous silhouette.`
        });
    }

    // Validation 3: Green engrave paths
    if (greenElements.length > 0) {
        validations.push({
            status: 'pass',
            message: `Found ${greenElements.length} green engrave path(s)`
        });
    } else {
        validations.push({
            status: 'warning',
            message: 'No green (#00FF00) engrave paths found (interior details)'
        });
    }

    // Validation 4: Check for non-standard colors
    if (otherElements.length > 0) {
        validations.push({
            status: 'fail',
            message: `Found ${otherElements.length} element(s) with non-standard colors. Only red and green allowed.`
        });
    } else {
        validations.push({
            status: 'pass',
            message: 'All elements use correct colors'
        });
    }

    // Validation 5: Check for fills (should be none or stroke-only)
    const elementsWithFill = Array.from(allElements).filter(el => {
        const fill = el.getAttribute('fill');
        return fill && fill !== 'none';
    });

    if (elementsWithFill.length === 0) {
        validations.push({
            status: 'pass',
            message: 'No problematic fills detected (stroke-only design)'
        });
    } else {
        validations.push({
            status: 'warning',
            message: `${elementsWithFill.length} element(s) have fill attributes. Laser design should use strokes only.`
        });
    }

    displayValidation(validations);
}

// Display validation results
function displayValidation(validations) {
    validationContent.innerHTML = validations.map(v => `
        <div class="validation-item ${v.status}">
            <span>${v.status === 'pass' ? '✓' : v.status === 'warning' ? '⚠' : '✗'}</span>
            <span>${v.message}</span>
        </div>
    `).join('');

    validationResults.style.display = 'block';
}

// Download SVG
downloadBtn.addEventListener('click', () => {
    if (!currentSVG) return;

    const blob = new Blob([currentSVG], { type: 'image/svg+xml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `laser-art-${currentSubject.replace(/\s+/g, '-')}.svg`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    showStatus('SVG downloaded successfully!', 'success');
});

// Copy SVG code
copySvgBtn.addEventListener('click', async () => {
    if (!currentSVG) return;

    try {
        await navigator.clipboard.writeText(currentSVG);
        showStatus('SVG code copied to clipboard!', 'success');
    } catch (error) {
        showStatus('Failed to copy SVG code', 'error');
    }
});

// Helper: Show status message
function showStatus(message, type) {
    statusMessage.textContent = message;
    statusMessage.className = `status-message ${type}`;
}

// Helper: Set loading state
function setLoading(loading) {
    generateBtn.disabled = loading;
    const btnText = generateBtn.querySelector('.btn-text');
    const btnLoader = generateBtn.querySelector('.btn-loader');

    if (loading) {
        btnText.style.display = 'none';
        btnLoader.style.display = 'inline';
    } else {
        btnText.style.display = 'inline';
        btnLoader.style.display = 'none';
    }
}

// Allow Enter key to trigger generation
subjectInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        generateBtn.click();
    }
});
