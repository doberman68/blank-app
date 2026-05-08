import xml.etree.ElementTree as ET

import streamlit as st

SYSTEM_PROMPT = """SYSTEM PROMPT -- Laser-Ready Vector Character Generator

(Red Cut / Green Engrave · Batch Safe · Production Locked)

You are a professional vector illustrator specializing exclusively in laser-cut and laser-engraved artwork for wood and similar materials.

Your output must always be manufacturing-ready and require zero cleanup in laser software such as LightBurn, Epilog, or Glowforge.

### Interaction Rule

At the start of each new generation, you MUST ask exactly:

"What object, animal, or person would you like to create?"

Do not proceed until an answer is provided.

---

## DESIGN REQUIREMENTS (MANDATORY)

### Style & Visual Language

- Simple, naïve, childlike illustration style
- Hand-drawn look with smooth, rounded geometry
- Friendly, minimal facial features where applicable
- No shading, gradients, textures, fills, or backgrounds
- Must resemble a small engraved wooden figurine or ornament

---

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

---

### 🟢 GREEN (#00FF00) -- ENGRAVE GEOMETRY ONLY
- Interior details ONLY
- Must sit entirely within the red cut boundary
- Single-stroke paths only
- No fills
- No overlapping or doubled lines
- No engraving marks outside the cut area

> Any green line outside the red silhouette is INVALID.

---

## VECTOR & PRODUCTION CONSTRAINTS

- Output must be true vector artwork (SVG-friendly)
- Stroke-based paths only (no raster elements)
- Avoid thin, fragile, or break-prone geometry
- Engrave details must remain legible in wood
- Clear, intentional separation between cut and engrave paths
- Red geometry must NEVER include non-essential strokes

---

## COMPOSITION RULES

- Centered, front-facing design
- Rounded, simplified proportions
- Balanced silhouette suitable for small laser-cut items
- Ornament-safe geometry (no accidental drop-outs)

---

## OUTPUT FORMAT RULES

- Produce one complete vector illustration
- White background only
- No text, labels, names, or decorative elements
- Do NOT rasterize or flatten
- Include a brief confirmation note stating:
  - Red paths = cut
  - Green paths = engrave

The final output must be immediately usable in laser software with zero manual correction.

---

### FAILURE CONDITIONS (DO NOT VIOLATE)

- Multiple red contours
- Red decorative strokes
- Green lines outside cut area
- Engraving details not supported by cut geometry
- Shading, fills, or raster elements

Any violation renders the output invalid.
"""

st.set_page_config(page_title="Laser-Ready Vector Generator", page_icon="🔴")

st.title("Laser-Ready Engrave + Cut Line Art")
st.write(
    "Generate manufacturing-safe SVG artwork for laser cutting and engraving. "
    "Use the prompt builder to feed your preferred model, then validate the SVG before production."
)

st.subheader("What object, animal, or person would you like to create?")
subject = st.text_input(
    "Subject",
    placeholder="e.g., a smiling fox holding a flower",
    label_visibility="collapsed",
)

st.divider()

st.subheader("1) Prompt Builder")

with st.expander("View system prompt", expanded=False):
    st.text(SYSTEM_PROMPT)

user_prompt = ""
if subject:
    user_prompt = f"Create a laser-ready vector illustration of: {subject}."

prompt_payload = ""
if user_prompt:
    prompt_payload = f"{SYSTEM_PROMPT}\n\nUSER REQUEST\n{user_prompt}"

st.text_area(
    "Prompt to send to your model",
    value=prompt_payload,
    height=360,
    placeholder="Enter a subject above to build the prompt.",
)

st.divider()

st.subheader("2) SVG Validation")
st.write(
    "Paste the SVG response from your model to validate basic production rules. "
    "This checks for red cut paths, green engrave paths, and disallowed fills."
)

svg_input = st.text_area("Paste SVG here", height=240)

if svg_input:
    try:
        root = ET.fromstring(svg_input)
        paths = root.findall(".//{http://www.w3.org/2000/svg}path")
        if not paths:
            paths = root.findall(".//path")

        red_paths = []
        green_paths = []
        filled_paths = []

        for path in paths:
            stroke = (path.attrib.get("stroke") or "").lower()
            fill = (path.attrib.get("fill") or "").lower()

            if stroke in {"#ff0000", "red", "rgb(255,0,0)"}:
                red_paths.append(path)
            if stroke in {"#00ff00", "green", "rgb(0,255,0)"}:
                green_paths.append(path)
            if fill and fill not in {"none", "transparent"}:
                filled_paths.append(path)

        issues = []
        if len(red_paths) != 1:
            issues.append("Expected exactly 1 red cut path.")
        if not green_paths:
            issues.append("Expected at least 1 green engrave path.")
        if filled_paths:
            issues.append("Remove fills; stroke-only paths are required.")

        if issues:
            st.error("Validation issues:\n" + "\n".join(f"• {issue}" for issue in issues))
        else:
            st.success("Basic validation passed. Review in your laser software before production.")
    except ET.ParseError:
        st.error("Invalid SVG XML. Please paste a valid SVG.")

st.divider()

st.subheader("3) Production Notes")
st.write(
    "- Red paths = cut\n"
    "- Green paths = engrave\n"
    "- Keep all engrave lines inside the cut silhouette"
)
