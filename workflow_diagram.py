import streamlit as st

st.set_page_config(
    page_title="AI Sales Enablement Hub – Workflow",
    page_icon="🗺️",
    layout="wide",
    initial_sidebar_state="collapsed",
)

DIAGRAM_HTML = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: 'Segoe UI', Arial, sans-serif;
    background: #0f1117;
    color: #e0e0e0;
    padding: 24px 16px 40px;
  }

  /* ── Header ── */
  .header {
    text-align: center;
    margin-bottom: 36px;
  }
  .header h1 {
    font-size: 1.9rem;
    font-weight: 700;
    color: #ffffff;
    letter-spacing: 0.5px;
  }
  .header p {
    margin-top: 6px;
    font-size: 0.95rem;
    color: #8899aa;
  }

  /* ── Layout: left column = flow, right column = detail cards ── */
  .layout {
    display: grid;
    grid-template-columns: 260px 1fr;
    gap: 0 32px;
    max-width: 1080px;
    margin: 0 auto;
    align-items: start;
  }

  /* ── Left: vertical flow spine ── */
  .flow-spine {
    display: flex;
    flex-direction: column;
    align-items: center;
    position: relative;
  }

  .flow-node {
    width: 220px;
    border-radius: 10px;
    padding: 12px 16px;
    text-align: center;
    position: relative;
    z-index: 1;
    cursor: default;
    transition: transform 0.15s ease, box-shadow 0.15s ease;
  }
  .flow-node:hover {
    transform: translateX(4px);
    box-shadow: 0 0 18px rgba(255,255,255,0.08);
  }

  .flow-node .step-num {
    font-size: 0.65rem;
    font-weight: 700;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    opacity: 0.7;
    margin-bottom: 4px;
  }
  .flow-node .step-icon {
    font-size: 1.4rem;
    margin-bottom: 4px;
  }
  .flow-node .step-title {
    font-size: 0.85rem;
    font-weight: 700;
    line-height: 1.3;
  }

  /* colour palette per stage */
  .c1 { background: #1a2540; border: 1.5px solid #3b5bdb; }
  .c2 { background: #1e1a40; border: 1.5px solid #7048e8; }
  .c3 { background: #1a2e30; border: 1.5px solid #0ca678; }
  .c4 { background: #2a1f10; border: 1.5px solid #f76707; }
  .c5 { background: #1a2a1a; border: 1.5px solid #2f9e44; }
  .c6 { background: #102030; border: 1.5px solid #1971c2; }
  .c7 { background: #2a2010; border: 1.5px solid #e67700; }
  .c8 { background: #1c1040; border: 1.5px solid #9775fa; }

  .c1 .step-title { color: #748ffc; }
  .c2 .step-title { color: #b197fc; }
  .c3 .step-title { color: #38d9a9; }
  .c4 .step-title { color: #fd7e14; }
  .c5 .step-title { color: #51cf66; }
  .c6 .step-title { color: #4dabf7; }
  .c7 .step-title { color: #fcc419; }
  .c8 .step-title { color: #cc5de8; }

  /* connector arrow between nodes */
  .arrow-down {
    width: 2px;
    height: 28px;
    background: linear-gradient(to bottom, #334155, #475569);
    position: relative;
    z-index: 0;
  }
  .arrow-down::after {
    content: '';
    position: absolute;
    bottom: -5px;
    left: 50%;
    transform: translateX(-50%);
    border-left: 5px solid transparent;
    border-right: 5px solid transparent;
    border-top: 6px solid #64748b;
  }

  /* feedback loop arc label */
  .feedback-arc {
    display: flex;
    align-items: center;
    gap: 6px;
    margin: 6px 0;
    padding: 5px 12px;
    border-radius: 20px;
    background: #1a1a2e;
    border: 1px dashed #7048e8;
    font-size: 0.72rem;
    color: #b197fc;
    font-weight: 600;
    letter-spacing: 0.5px;
  }

  /* ── Right: detail cards grid ── */
  .detail-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 14px;
    align-content: start;
  }

  .detail-card {
    border-radius: 10px;
    padding: 14px 16px;
    border-top: 3px solid;
  }
  .detail-card h3 {
    font-size: 0.8rem;
    font-weight: 700;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    margin-bottom: 8px;
  }
  .detail-card ul {
    list-style: none;
    padding: 0;
  }
  .detail-card ul li {
    font-size: 0.78rem;
    color: #b0c4d8;
    padding: 3px 0;
    display: flex;
    align-items: flex-start;
    gap: 7px;
    line-height: 1.4;
  }
  .detail-card ul li::before {
    content: '▸';
    flex-shrink: 0;
    margin-top: 1px;
  }

  .dc1 { background: #111827; border-color: #3b5bdb; }
  .dc1 h3 { color: #748ffc; }
  .dc2 { background: #111827; border-color: #7048e8; }
  .dc2 h3 { color: #b197fc; }
  .dc3 { background: #111827; border-color: #0ca678; }
  .dc3 h3 { color: #38d9a9; }
  .dc4 { background: #111827; border-color: #f76707; }
  .dc4 h3 { color: #fd7e14; }
  .dc5 { background: #111827; border-color: #2f9e44; }
  .dc5 h3 { color: #51cf66; }
  .dc6 { background: #111827; border-color: #1971c2; }
  .dc6 h3 { color: #4dabf7; }
  .dc7 { background: #111827; border-color: #e67700; }
  .dc7 h3 { color: #fcc419; }
  .dc8 { background: #111827; border-color: #9775fa; }
  .dc8 h3 { color: #cc5de8; }

  /* ── KPI bar at bottom ── */
  .kpi-bar {
    max-width: 1080px;
    margin: 36px auto 0;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 14px;
  }
  .kpi-card {
    background: #111827;
    border-radius: 10px;
    padding: 14px 18px;
    border: 1px solid #1e3a5f;
  }
  .kpi-card h4 {
    font-size: 0.75rem;
    font-weight: 700;
    letter-spacing: 1px;
    text-transform: uppercase;
    color: #4dabf7;
    margin-bottom: 8px;
  }
  .kpi-card ul {
    list-style: none;
    padding: 0;
  }
  .kpi-card ul li {
    font-size: 0.78rem;
    color: #94a3b8;
    padding: 2px 0;
    display: flex;
    align-items: flex-start;
    gap: 6px;
  }
  .kpi-card ul li::before { content: '●'; color: #3b5bdb; font-size: 0.5rem; margin-top: 4px; }

  /* ── Tagline ── */
  .tagline {
    max-width: 1080px;
    margin: 28px auto 0;
    text-align: center;
    font-size: 0.88rem;
    color: #64748b;
    font-style: italic;
  }
  .tagline strong { color: #94a3b8; font-style: normal; }
</style>
</head>
<body>

<!-- ── Header ── -->
<div class="header">
  <h1>AI Sales Enablement Hub</h1>
  <p>Use-Case Driven Learning System &nbsp;·&nbsp; End-to-End Operational Workflow</p>
</div>

<!-- ── Main two-column layout ── -->
<div class="layout">

  <!-- Left: Flow spine -->
  <div class="flow-spine">

    <div class="flow-node c1">
      <div class="step-num">Step 01</div>
      <div class="step-icon">🔍</div>
      <div class="step-title">Tool &amp; Use Case Intake</div>
    </div>
    <div class="arrow-down"></div>

    <div class="flow-node c2">
      <div class="step-num">Step 02</div>
      <div class="step-icon">📐</div>
      <div class="step-title">Use Case Definition</div>
    </div>
    <div class="arrow-down"></div>

    <div class="flow-node c3">
      <div class="step-num">Step 03</div>
      <div class="step-icon">🗺️</div>
      <div class="step-title">Tool Mapping</div>
    </div>
    <div class="arrow-down"></div>

    <div class="flow-node c4">
      <div class="step-num">Step 04</div>
      <div class="step-icon">🎬</div>
      <div class="step-title">AI Content Creation</div>
    </div>
    <div class="arrow-down"></div>

    <div class="flow-node c5">
      <div class="step-num">Step 05</div>
      <div class="step-icon">📤</div>
      <div class="step-title">Publish to Hub</div>
    </div>
    <div class="arrow-down"></div>

    <div class="flow-node c6">
      <div class="step-num">Step 06</div>
      <div class="step-icon">🔎</div>
      <div class="step-title">Rep Access &amp; Consumption</div>
    </div>
    <div class="arrow-down"></div>

    <div class="flow-node c7">
      <div class="step-num">Step 07</div>
      <div class="step-icon">📊</div>
      <div class="step-title">Feedback &amp; Analytics</div>
    </div>
    <div class="arrow-down"></div>

    <div class="flow-node c8">
      <div class="step-num">Step 08</div>
      <div class="step-icon">♻️</div>
      <div class="step-title">Continuous Update Cycle</div>
    </div>

    <div class="arrow-down" style="height:20px"></div>
    <div class="feedback-arc">↩ loops back to Step 02</div>

  </div>

  <!-- Right: Detail cards -->
  <div class="detail-grid">

    <div class="detail-card dc1">
      <h3>01 · Intake</h3>
      <ul>
        <li>Audit existing AI tools across HP ecosystem</li>
        <li>Collect rep &amp; manager pain points</li>
        <li>Source insights from CRM data &amp; enablement teams</li>
        <li>Prioritise high-value use cases</li>
      </ul>
    </div>

    <div class="detail-card dc2">
      <h3>02 · Use Case Definition</h3>
      <ul>
        <li>Define trigger: when does this happen in the deal?</li>
        <li>Set objective: what outcome should result?</li>
        <li>Standardise recommended workflow steps</li>
        <li>Validate with frontline sellers &amp; managers</li>
      </ul>
    </div>

    <div class="detail-card dc3">
      <h3>03 · Tool Mapping</h3>
      <ul>
        <li>Assign primary tool per use case</li>
        <li>Identify supporting / complementary tools</li>
        <li>Define step-by-step best-practice sequence</li>
        <li>Flag tool overlaps &amp; redundancies</li>
      </ul>
    </div>

    <div class="detail-card dc4">
      <h3>04 · AI Content Creation (Guidde)</h3>
      <ul>
        <li>Record workflow screen-capture once</li>
        <li>Auto-generate voiceover &amp; step-by-step captions</li>
        <li>Target: &lt; 2-minute videos only</li>
        <li>Store as reusable, version-controlled asset</li>
      </ul>
    </div>

    <div class="detail-card dc5">
      <h3>05 · Publish to Hub</h3>
      <ul>
        <li>Upload to SharePoint / Seismic / internal portal</li>
        <li>Tag by use case, tool, sales stage &amp; persona</li>
        <li>QA check: correct tool, accurate steps, clear outcome</li>
        <li>Announce to field via Slack / manager comms</li>
      </ul>
    </div>

    <div class="detail-card dc6">
      <h3>06 · Rep Access</h3>
      <ul>
        <li>Search by need — not by tool name</li>
        <li>Select matching use case from taxonomy</li>
        <li>Watch 1–2 min walkthrough</li>
        <li>Execute immediately inside their workflow</li>
      </ul>
    </div>

    <div class="detail-card dc7">
      <h3>07 · Feedback &amp; Analytics</h3>
      <ul>
        <li>Track: views, completions, time-to-execute</li>
        <li>Capture rep ratings &amp; open-text feedback</li>
        <li>Identify gaps, new use cases, outdated content</li>
        <li>Surface tool-change alerts from product updates</li>
      </ul>
    </div>

    <div class="detail-card dc8">
      <h3>08 · Continuous Update</h3>
      <ul>
        <li>Re-record only when tool UI or workflow changes</li>
        <li>Guidde auto-regenerates updated content</li>
        <li>No manual retraining sessions required</li>
        <li>Versioned history maintained for rollback</li>
      </ul>
    </div>

  </div>
</div>

<!-- ── KPI Bar ── -->
<div class="kpi-bar">
  <div class="kpi-card">
    <h4>Adoption Metrics</h4>
    <ul>
      <li>% of reps accessing hub weekly</li>
      <li>Tool utilisation rate (pre vs post)</li>
      <li>Video completion rate</li>
    </ul>
  </div>
  <div class="kpi-card">
    <h4>Productivity Metrics</h4>
    <ul>
      <li>Time-to-complete key sales tasks</li>
      <li>CRM data completeness score</li>
      <li>Ramp time for new hires</li>
    </ul>
  </div>
  <div class="kpi-card">
    <h4>Sales Impact</h4>
    <ul>
      <li>Pipeline velocity (correlated to usage)</li>
      <li>Win rate improvement</li>
      <li>Deal cycle duration</li>
    </ul>
  </div>
</div>

<div class="tagline">
  <strong>"This is not another tool."</strong> &nbsp;—&nbsp;
  A translation layer between AI capabilities and repeatable sales execution.
</div>

</body>
</html>
"""

st.components.v1.html(DIAGRAM_HTML, height=1080, scrolling=True)
