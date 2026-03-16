import streamlit as st

# Ohanami scoring rules:
# - 3 rounds; each round more colors become active
# - Round 1: Blue cards only
# - Round 2: Blue + Pink cards
# - Round 3: Blue + Pink + Green cards
# - Score for n cards of one color = n * (n + 1) / 2 (triangular number)

COLORS = {
    "Blue": {"emoji": "🔵", "rounds": [1, 2, 3]},
    "Pink": {"emoji": "🌸", "rounds": [2, 3]},
    "Green": {"emoji": "🌿", "rounds": [3]},
}

MAX_CARDS_PER_COLOR = 20


def score_for_count(n: int) -> int:
    """Triangular number: n*(n+1)/2"""
    return n * (n + 1) // 2


def active_colors_for_round(round_num: int) -> list[str]:
    return [c for c, info in COLORS.items() if round_num in info["rounds"]]


st.set_page_config(page_title="Ohanami Scoring", page_icon="🌸", layout="wide")
st.title("🌸 Ohanami Scoring Calculator")

st.markdown(
    """
**How scoring works:**
- Each color scores **n × (n+1) / 2** points (where n = number of cards)
- **Round 1** — 🔵 Blue cards score
- **Round 2** — 🔵 Blue + 🌸 Pink cards score
- **Round 3** — 🔵 Blue + 🌸 Pink + 🌿 Green cards score
"""
)

st.divider()

# --- Player setup ---
with st.sidebar:
    st.header("⚙️ Game Setup")
    num_players = st.number_input("Number of players", min_value=2, max_value=6, value=2, step=1)
    player_names = []
    for i in range(num_players):
        name = st.text_input(f"Player {i + 1} name", value=f"Player {i + 1}", key=f"name_{i}")
        player_names.append(name.strip() or f"Player {i + 1}")

    st.divider()
    st.header("📋 Scoring Reference")
    ref_data = {"Cards": list(range(0, 13)), "Points": [score_for_count(n) for n in range(13)]}
    st.dataframe(ref_data, hide_index=True, use_container_width=True)

# --- Card counts per round per player ---
if "card_counts" not in st.session_state:
    st.session_state.card_counts = {}

# Initialize / reset missing entries
for p in player_names:
    if p not in st.session_state.card_counts:
        st.session_state.card_counts[p] = {r: {c: 0 for c in COLORS} for r in [1, 2, 3]}

tabs = st.tabs(["Round 1", "Round 2", "Round 3", "📊 Scoreboard"])

for round_idx, tab in enumerate(tabs[:3]):
    round_num = round_idx + 1
    active = active_colors_for_round(round_num)

    with tab:
        st.subheader(f"Round {round_num} — Active: " + "  ".join(f"{COLORS[c]['emoji']} {c}" for c in active))
        cols = st.columns(num_players)

        for p_idx, player in enumerate(player_names):
            with cols[p_idx]:
                st.markdown(f"**{player}**")
                for color in COLORS:
                    emoji = COLORS[color]["emoji"]
                    disabled = color not in active
                    val = st.number_input(
                        f"{emoji} {color}",
                        min_value=0,
                        max_value=MAX_CARDS_PER_COLOR,
                        value=st.session_state.card_counts[player][round_num][color],
                        step=1,
                        key=f"r{round_num}_{player}_{color}",
                        disabled=disabled,
                        label_visibility="visible",
                    )
                    if not disabled:
                        st.session_state.card_counts[player][round_num][color] = val

                # Show round subtotal
                round_pts = sum(
                    score_for_count(st.session_state.card_counts[player][round_num][c])
                    for c in active
                )
                st.metric("Round points", round_pts)

# --- Scoreboard tab ---
with tabs[3]:
    st.subheader("Scoreboard")

    # Build per-player per-round scores
    round_scores = {p: [] for p in player_names}
    cumulative = {p: 0 for p in player_names}

    rows = []
    for round_num in [1, 2, 3]:
        active = active_colors_for_round(round_num)
        row = {"Round": f"Round {round_num}"}
        for player in player_names:
            pts = sum(
                score_for_count(st.session_state.card_counts[player][round_num][c])
                for c in active
            )
            round_scores[player].append(pts)
            cumulative[player] += pts
            row[player] = pts
        rows.append(row)

    # Total row
    total_row = {"Round": "**Total**"}
    for player in player_names:
        total_row[player] = cumulative[player]
    rows.append(total_row)

    st.dataframe(rows, hide_index=True, use_container_width=True)

    st.divider()

    # Winner announcement
    max_score = max(cumulative.values())
    winners = [p for p, s in cumulative.items() if s == max_score]

    if max_score == 0:
        st.info("Enter card counts in each round to see results.")
    elif len(winners) == 1:
        st.success(f"🏆 Winner: **{winners[0]}** with **{max_score} points**!")
    else:
        st.warning(f"🤝 Tie! **{' and '.join(winners)}** each have **{max_score} points**!")

    # Per-player breakdown
    st.subheader("Detailed Breakdown")
    detail_cols = st.columns(num_players)
    for p_idx, player in enumerate(player_names):
        with detail_cols[p_idx]:
            st.markdown(f"**{player}** — {cumulative[player]} pts total")
            for round_num in [1, 2, 3]:
                active = active_colors_for_round(round_num)
                with st.expander(f"Round {round_num}: {round_scores[player][round_num - 1]} pts"):
                    for color in active:
                        n = st.session_state.card_counts[player][round_num][color]
                        pts = score_for_count(n)
                        st.write(f"{COLORS[color]['emoji']} {color}: {n} cards → {pts} pts")
