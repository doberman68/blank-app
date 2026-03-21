import re
import requests
import streamlit as st
from bs4 import BeautifulSoup
from urllib.parse import urlparse

JUSTTHERECIPE_BASE = "https://www.justtherecipe.com/?url="

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )
}


def extract_recipe_name(url: str) -> str:
    """Fetch the page and extract a clean recipe name."""
    response = requests.get(url, headers=HEADERS, timeout=10)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")

    # Try JSON-LD schema first (most reliable for recipe sites)
    import json
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or "")
            # Handle @graph array
            if isinstance(data, dict) and data.get("@graph"):
                data = data["@graph"]
            if isinstance(data, list):
                for item in data:
                    if isinstance(item, dict) and item.get("@type") in ("Recipe", "recipe"):
                        return item.get("name", "").strip()
            if isinstance(data, dict) and data.get("@type") in ("Recipe", "recipe"):
                return data.get("name", "").strip()
        except (json.JSONDecodeError, AttributeError):
            continue

    # Try og:title meta tag
    og_title = soup.find("meta", property="og:title")
    if og_title and og_title.get("content"):
        return clean_title(og_title["content"])

    # Try h1
    h1 = soup.find("h1")
    if h1:
        return clean_title(h1.get_text())

    # Fall back to <title>
    if soup.title and soup.title.string:
        return clean_title(soup.title.string)

    return "Recipe"


def clean_title(title: str) -> str:
    """Strip site name suffixes and extra whitespace from a page title."""
    title = title.strip()
    # Remove site name suffixes after common separators (must have surrounding spaces)
    title = re.split(r"\s+[|\-–—]\s+", title)[0].strip()
    return title


def is_valid_url(url: str) -> bool:
    try:
        result = urlparse(url)
        return result.scheme in ("http", "https") and bool(result.netloc)
    except ValueError:
        return False


# ─── Page Config ───────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Recipe Cleaner",
    page_icon="🍽️",
    layout="centered",
)

# ─── Header ────────────────────────────────────────────────────────────────────
st.title("🍽️ Clean Recipe Generator")
st.markdown(
    "Paste any recipe URL and get a clean, clutter-free version — "
    "no ads, no popups, no life stories."
)
st.markdown("---")

# ─── Input ─────────────────────────────────────────────────────────────────────
url_input = st.text_input(
    "Recipe URL",
    placeholder="https://www.example.com/my-amazing-pasta-recipe",
    label_visibility="collapsed",
)

get_btn = st.button("Get Recipe", type="primary", use_container_width=True)

# ─── Output ────────────────────────────────────────────────────────────────────
if get_btn:
    url = url_input.strip()

    if not url:
        st.warning("Please paste a recipe URL above.")
    elif not is_valid_url(url):
        st.error("That doesn't look like a valid URL. Make sure it starts with https://")
    else:
        with st.spinner("Fetching recipe name..."):
            try:
                recipe_name = extract_recipe_name(url)
                clean_url = JUSTTHERECIPE_BASE + url

                share_text = (
                    f'Check out this recipe for "{recipe_name}" on JustTheRecipe! '
                    f"{clean_url}"
                )

                st.success("Recipe found!")

                st.markdown(f"### {recipe_name}")

                st.markdown("**Share this clean recipe:**")
                st.code(share_text, language=None)

                st.link_button(
                    "Open Clean Recipe",
                    clean_url,
                    type="primary",
                    use_container_width=True,
                )

                st.markdown("**Preview:**")
                st.components.v1.iframe(clean_url, height=600, scrolling=True)

            except requests.exceptions.ConnectionError:
                st.error("Could not reach that URL. Please check it and try again.")
            except requests.exceptions.Timeout:
                st.error("The request timed out. The site may be slow — try again.")
            except requests.exceptions.HTTPError as e:
                st.error(f"The site returned an error: {e}")
            except Exception as e:
                st.error(f"Something went wrong: {e}")

# ─── Footer ────────────────────────────────────────────────────────────────────
st.markdown("---")
st.markdown(
    "<div style='text-align:center; color: #888; font-size: 0.85em;'>"
    "Powered by JustTheRecipe · Built with Streamlit"
    "</div>",
    unsafe_allow_html=True,
)
