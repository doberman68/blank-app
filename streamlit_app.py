import json
import streamlit as st
import anthropic

SAMPLE_JSON = """{
  "prompt": "A cinematic futuristic corporate portrait of a young professional working on a sleek laptop in a modern high-tech office environment, neon blue and magenta color palette, cyberpunk-inspired but polished and corporate, soft glowing light, luminous skin tones, dreamy atmospheric haze, blurred city lights and abstract digital interface elements in the background, shallow depth of field, elegant and focused expression, modern minimal clothing, reflective surfaces, immersive ambient lighting, ultra-detailed digital art, smooth gradients, vibrant pink and electric blue glow, premium tech campaign aesthetic, clean composition, high-end branding look, sophisticated, inspirational, modern AI and automation theme, visually striking, glossy, realistic illustration, 16:9 widescreen",
  "style": {
    "genre": "futuristic corporate tech",
    "mood": "sophisticated, inspirational, calm, innovative",
    "visual_influences": [
      "cyberpunk-inspired",
      "premium enterprise branding",
      "cinematic digital illustration",
      "modern AI campaign artwork"
    ]
  },
  "subject": {
    "type": "young professional woman",
    "pose": "focused, seated, typing on a laptop",
    "expression": "calm, intelligent, concentrated",
    "wardrobe": "modern minimal professional clothing"
  },
  "environment": {
    "setting": "modern high-tech office",
    "background": [
      "blurred city lights",
      "abstract digital interface elements",
      "ambient glow",
      "subtle atmospheric haze"
    ],
    "surfaces": [
      "reflective desk",
      "sleek laptop",
      "clean modern workspace"
    ]
  },
  "lighting": {
    "primary_colors": [
      "electric blue",
      "vibrant magenta",
      "pink neon"
    ],
    "effects": [
      "soft neon bloom",
      "volumetric glow",
      "cinematic lighting",
      "smooth gradients"
    ]
  },
  "composition": {
    "aspect_ratio": "16:9",
    "framing": "medium close-up",
    "depth_of_field": "shallow",
    "focus": "subject face and laptop",
    "style_notes": [
      "clean composition",
      "high-end campaign aesthetic",
      "balanced negative space",
      "immersive framing"
    ]
  },
  "quality": {
    "render_style": "glossy realistic illustration",
    "detail_level": "ultra-detailed",
    "resolution": "high resolution"
  },
  "theme": [
    "AI",
    "automation",
    "innovation",
    "enterprise technology",
    "digital transformation"
  ],
  "negative_prompt": [
    "low resolution",
    "blurry face",
    "distorted hands",
    "extra fingers",
    "cluttered background",
    "harsh shadows",
    "noisy image",
    "text artifacts",
    "watermark",
    "poor anatomy",
    "overexposed highlights",
    "cartoonish proportions",
    "messy composition"
  ]
}"""

MODEL_CONFIGS = {
    "Midjourney": {
        "icon": "🎨",
        "description": "Optimized with MJ parameters (--ar, --style, --v, --q)",
    },
    "DALL-E 3": {
        "icon": "🖼️",
        "description": "Natural language, vivid style, OpenAI format",
    },
    "Stable Diffusion XL": {
        "icon": "⚙️",
        "description": "Tag-based with weighted terms and negative prompt",
    },
    "Adobe Firefly": {
        "icon": "🔥",
        "description": "Clean descriptive language, content credentials safe",
    },
    "Leonardo AI": {
        "icon": "🦁",
        "description": "Detailed prompt with Leonardo-specific quality tags",
    },
    "Ideogram": {
        "icon": "💡",
        "description": "Balanced prompt with magic prompt enhancement style",
    },
}

SYSTEM_PROMPT = """You are an expert AI image prompt engineer. Your job is to transform structured JSON image data into highly optimized, platform-specific prompts for AI image generation models.

For each model, follow its unique syntax, conventions, and best practices:

- **Midjourney**: Use concise, evocative language. Append parameters like --ar 16:9 --style raw --v 6.1 --q 2. Use :: weighting for emphasis. Structure: [subject], [environment], [lighting], [style], [mood] --params
- **DALL-E 3**: Write in natural, descriptive prose. Be specific about style (photorealistic, digital art, etc.). Avoid banned terms. OpenAI's system enhances prompts, so keep instructions clear and detailed.
- **Stable Diffusion XL**: Use comma-separated tags. Apply (term:weight) syntax for emphasis e.g. (neon lights:1.4). Include quality tags like masterpiece, best quality. Always include a negative prompt section.
- **Adobe Firefly**: Use clean, descriptive language. Avoid copyrighted references. Focus on mood, style, and technical descriptors. Content-safe and commercially viable.
- **Leonardo AI**: Detailed natural language with Leonardo-style quality tags (hyper-detailed, cinematic lighting, 8k uhd). Include style references from Leonardo's presets when relevant.
- **Ideogram**: Balanced descriptive prompt. Works well with typography if needed. Include style modifiers clearly. Structured for magic prompt compatibility.

Always extract and use ALL relevant information from the JSON: subject, environment, lighting, composition, style, mood, quality, and themes. The negative_prompt field should inform what to avoid in each platform's negative prompt format (where supported).

Output ONLY the requested prompts with clear section headers. No explanations unless asked."""


def build_user_message(json_data: dict, selected_models: list) -> str:
    models_list = "\n".join(f"- {m}" for m in selected_models)
    return f"""Generate optimized image prompts for the following AI models based on the JSON data below.

**Target Models:**
{models_list}

**JSON Image Data:**
```json
{json.dumps(json_data, indent=2)}
```

For each model, provide:
1. A section header with the model name
2. The optimized prompt (ready to copy-paste)
3. For models that support it, a negative prompt on a separate labeled line

Format each section clearly separated by a divider line."""


def stream_prompts(json_data: dict, selected_models: list, api_key: str):
    client = anthropic.Anthropic(api_key=api_key)
    user_message = build_user_message(json_data, selected_models)

    with client.messages.stream(
        model="claude-opus-4-6",
        max_tokens=4096,
        thinking={"type": "adaptive"},
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    ) as stream:
        for text in stream.text_stream:
            yield text


# ─── Page Config ───────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="AI Image Prompt Generator",
    page_icon="🎨",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ─── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.title("⚙️ Settings")
    st.markdown("---")

    api_key = st.text_input(
        "Anthropic API Key",
        type="password",
        placeholder="sk-ant-...",
        help="Your Anthropic API key. Get one at console.anthropic.com",
    )

    st.markdown("---")
    st.subheader("🎯 Target Models")
    st.caption("Select which AI models to generate prompts for:")

    selected_models = []
    for model_name, config in MODEL_CONFIGS.items():
        checked = st.checkbox(
            f"{config['icon']} {model_name}",
            value=True,
            help=config["description"],
        )
        if checked:
            selected_models.append(model_name)

    st.markdown("---")
    st.caption("Powered by Claude Opus 4.6 with adaptive thinking")

# ─── Main Content ──────────────────────────────────────────────────────────────
st.title("🎨 AI Image Prompt Generator")
st.markdown(
    "Paste your image analysis JSON and generate optimized prompts for any AI image model."
)

col1, col2 = st.columns([1, 1], gap="large")

with col1:
    st.subheader("📋 Input JSON")
    st.caption("Paste your image analysis JSON data below:")

    json_input = st.text_area(
        label="JSON Data",
        value=SAMPLE_JSON,
        height=500,
        label_visibility="collapsed",
        placeholder="Paste your JSON here...",
    )

    # Validate JSON
    json_valid = False
    json_data = None
    if json_input.strip():
        try:
            json_data = json.loads(json_input)
            json_valid = True
            st.success("✅ Valid JSON")
        except json.JSONDecodeError as e:
            st.error(f"❌ Invalid JSON: {e}")

    # JSON preview expander
    if json_valid and json_data:
        with st.expander("🔍 JSON Structure Preview"):
            keys = list(json_data.keys())
            st.markdown(f"**Top-level keys:** {', '.join(f'`{k}`' for k in keys)}")
            if "subject" in json_data:
                subj = json_data["subject"]
                st.markdown(
                    f"**Subject:** {subj.get('type', 'N/A')} — {subj.get('pose', 'N/A')}"
                )
            if "style" in json_data:
                style = json_data["style"]
                st.markdown(f"**Genre:** {style.get('genre', 'N/A')}")
                st.markdown(f"**Mood:** {style.get('mood', 'N/A')}")
            if "composition" in json_data:
                comp = json_data["composition"]
                st.markdown(
                    f"**Aspect Ratio:** {comp.get('aspect_ratio', 'N/A')} | "
                    f"**Framing:** {comp.get('framing', 'N/A')}"
                )

with col2:
    st.subheader("✨ Generated Prompts")

    generate_btn = st.button(
        "🚀 Generate Prompts",
        type="primary",
        disabled=not (json_valid and api_key and selected_models),
        use_container_width=True,
    )

    if not api_key:
        st.info("👈 Enter your Anthropic API key in the sidebar to get started.")
    elif not json_valid:
        st.warning("⚠️ Fix the JSON input on the left to continue.")
    elif not selected_models:
        st.warning("⚠️ Select at least one target model in the sidebar.")

    output_container = st.empty()

    if generate_btn and json_valid and api_key and selected_models:
        output_container.empty()
        result_placeholder = st.empty()
        full_response = ""

        with st.spinner(f"Generating prompts for {len(selected_models)} model(s)..."):
            try:
                result_placeholder.markdown("_Generating..._")
                for chunk in stream_prompts(json_data, selected_models, api_key):
                    full_response += chunk
                    result_placeholder.markdown(full_response)

                # Store result in session state for copy functionality
                st.session_state["last_result"] = full_response
                result_placeholder.markdown(full_response)

            except anthropic.AuthenticationError:
                result_placeholder.error(
                    "❌ Invalid API key. Please check your Anthropic API key."
                )
            except anthropic.RateLimitError:
                result_placeholder.error(
                    "❌ Rate limit reached. Please wait a moment and try again."
                )
            except anthropic.BadRequestError as e:
                result_placeholder.error(f"❌ Bad request: {e}")
            except Exception as e:
                result_placeholder.error(f"❌ Unexpected error: {e}")

    elif "last_result" in st.session_state:
        st.markdown(st.session_state["last_result"])
        st.markdown("---")
        if st.button("📋 Copy All to Clipboard", use_container_width=True):
            st.code(st.session_state["last_result"], language=None)
            st.caption("Select all text above (Ctrl+A) and copy.")

# ─── Footer ────────────────────────────────────────────────────────────────────
st.markdown("---")
st.markdown(
    "<div style='text-align:center; color: #888; font-size: 0.85em;'>"
    "AI Image Prompt Generator · Powered by Claude Opus 4.6"
    "</div>",
    unsafe_allow_html=True,
)
