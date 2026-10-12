# 🎈 Blank app template

A simple Streamlit app template for you to modify!

[![Open in Streamlit](https://static.streamlit.io/badges/streamlit_badge_black_white.svg)](https://blank-app-template.streamlit.app/)

### How to run it on your own machine

1. Install the requirements

   ```
   $ pip install -r requirements.txt
   ```

2. Run the app

   ```
   $ streamlit run streamlit_app.py
   ```

## Auto Model (Claude Code mod)

Picks the main model once per session, locks it to protect the prompt cache, and sends small side jobs to a helper agent. Install it from a terminal Claude Code session:

```
/plugin install auto-model --marketplace doberman68/blank-app
```

Answer `y` to add the marketplace, pick the user scope, then run `/automodel on`.
