from __future__ import annotations
import re
import textwrap
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

import streamlit as st
from svgpathtools import parse_path


st.set_page_config(
    page_title="Laser Cutter SVG Optimizer",
    page_icon="🛠️",
    layout="wide",
)


@dataclass
class OptimizationReport:
    removed_hidden: int = 0
    precision_adjusted: int = 0
    sorted_paths: int = 0
    cut_elements: int = 0
    engrave_elements: int = 0


NUMERIC_ATTRS = {
    "d",
    "x",
    "y",
    "x1",
    "x2",
    "y1",
    "y2",
    "cx",
    "cy",
    "r",
    "rx",
    "ry",
    "width",
    "height",
    "points",
}


HIDDEN_TOKENS = {"display:none", "visibility:hidden", "opacity:0"}


def strip_namespace(tag: str) -> str:
    return tag.split("}", 1)[-1]


def round_numeric_string(value: str, precision: int) -> str:
    pattern = re.compile(r"(-?\d*\.\d+|-?\d+)")

    def repl(match: re.Match[str]) -> str:
        number = float(match.group(0))
        formatted = ("{0:." + str(precision) + "f}").format(number)
        return formatted.rstrip("0").rstrip(".")

    return pattern.sub(repl, value)


def parse_style(style: Optional[str]) -> Dict[str, str]:
    if not style:
        return {}
    parts = [item.strip() for item in style.split(";") if item.strip()]
    kv: Dict[str, str] = {}
    for part in parts:
        if ":" in part:
            key, value = part.split(":", 1)
            kv[key.strip()] = value.strip()
    return kv


def style_to_string(style_dict: Dict[str, str]) -> str:
    return ";".join(f"{k}:{v}" for k, v in style_dict.items())


def remove_hidden_elements(root: ET.Element, report: OptimizationReport) -> None:
    for parent in list(root.iter()):
        for child in list(parent):
            style_tokens = parse_style(child.get("style"))
            attr_tokens = {f"{k}:{v}" for k, v in style_tokens.items()}
            attr_tokens |= {
                f"{k}:{child.get(k)}"
                for k in ("display", "visibility", "opacity")
                if child.get(k)
            }
            if any(token in HIDDEN_TOKENS for token in attr_tokens):
                parent.remove(child)
                report.removed_hidden += 1


def round_numeric_values(root: ET.Element, precision: int, report: OptimizationReport) -> None:
    if precision < 0:
        return
    for elem in root.iter():
        for attr in NUMERIC_ATTRS:
            current = elem.get(attr)
            if current is None:
                continue
            new_value = round_numeric_string(current, precision)
            if new_value != current:
                elem.set(attr, new_value)
                report.precision_adjusted += 1
        style_string = elem.get("style")
        if style_string:
            style_dict = parse_style(style_string)
            changed = False
            for key in ("stroke-width", "opacity", "fill-opacity"):
                if key in style_dict:
                    rounded = round_numeric_string(style_dict[key], precision)
                    if rounded != style_dict[key]:
                        style_dict[key] = rounded
                        changed = True
            if changed:
                elem.set("style", style_to_string(style_dict))
                report.precision_adjusted += 1


def _stroke_width_from_style(style: Dict[str, str], element: ET.Element) -> Optional[float]:
    candidate = style.get("stroke-width") or element.get("stroke-width")
    if not candidate:
        return None
    match = re.match(r"(-?\d*\.\d+|-?\d+)", candidate)
    if not match:
        return None
    try:
        return float(match.group(0))
    except ValueError:
        return None


def classify_operation(element: ET.Element, threshold: float) -> str:
    style_dict = parse_style(element.get("style"))
    stroke_width = _stroke_width_from_style(style_dict, element)
    if stroke_width is None:
        return "engrave"
    return "cut" if stroke_width <= threshold else "engrave"


def apply_operation_coloring(
    root: ET.Element,
    threshold: float,
    cut_color: str,
    engrave_color: str,
    report: OptimizationReport,
) -> None:
    for elem in root.iter():
        tag = strip_namespace(elem.tag)
        if tag not in {"path", "line", "polyline", "polygon", "rect", "circle", "ellipse"}:
            continue
        style_dict = parse_style(elem.get("style"))
        operation = classify_operation(elem, threshold)
        if operation == "cut":
            style_dict["stroke"] = cut_color
            style_dict["fill"] = "none"
            style_dict.setdefault("stroke-width", "0.1")
            report.cut_elements += 1
        else:
            style_dict["stroke"] = "none"
            style_dict["fill"] = engrave_color
            style_dict.setdefault("fill-opacity", "1")
            report.engrave_elements += 1
        elem.set("style", style_to_string(style_dict))


def _path_bbox(element: ET.Element) -> Optional[Tuple[float, float, float, float]]:
    d_attr = element.get("d")
    if not d_attr:
        return None
    try:
        path = parse_path(d_attr)
        bbox = path.bbox()
        if bbox == (float("inf"),) * 4:
            return None
        return bbox
    except Exception:
        return None


def reorder_paths_for_travel(root: ET.Element, report: OptimizationReport) -> None:
    for parent in list(root.iter()):
        children = list(parent)
        path_entries: List[Tuple[ET.Element, Tuple[float, float, float, float]]] = []
        for child in children:
            if strip_namespace(child.tag) != "path":
                continue
            bbox = _path_bbox(child)
            if bbox is None:
                continue
            path_entries.append((child, bbox))
        if not path_entries:
            continue
        for child, _ in path_entries:
            parent.remove(child)
        path_entries.sort(key=lambda item: (item[1][0], item[1][2]))
        for child, _ in path_entries:
            parent.append(child)
            report.sorted_paths += 1


def optimize_svg(
    svg_content: str,
    precision: int,
    threshold: float,
    cut_color: str,
    engrave_color: str,
    do_remove_hidden: bool,
    do_round_numbers: bool,
    do_reorder_paths: bool,
) -> Tuple[str, OptimizationReport]:
    try:
        root = ET.fromstring(svg_content)
    except ET.ParseError as exc:
        raise ValueError(f"Unable to parse SVG file: {exc}") from exc

    report = OptimizationReport()
    if do_remove_hidden:
        remove_hidden_elements(root, report)
    if do_round_numbers:
        round_numeric_values(root, precision, report)
    apply_operation_coloring(root, threshold, cut_color, engrave_color, report)
    if do_reorder_paths:
        reorder_paths_for_travel(root, report)

    svg_bytes = ET.tostring(root, encoding="unicode")
    return svg_bytes, report


def main() -> None:
    st.title("🛠️ Laser Cutter SVG Optimizer")
    st.write(
        textwrap.dedent(
            """
            Upload an SVG exported from your design tool and apply optimizations tailored for
            laser cutting and engraving. The optimizer normalizes stroke/fill colors for different
            operations, trims unused data, and can reorder vector paths to reduce head travel.
            """
        ).strip()
    )

    uploaded_file = st.file_uploader("SVG file", type=["svg"])

    with st.sidebar:
        st.header("Optimization settings")
        remove_hidden = st.checkbox("Remove hidden elements", value=True)
        round_numbers = st.checkbox("Round numeric precision", value=True)
        precision = st.slider("Decimal precision", min_value=0, max_value=5, value=3)
        reorder_paths = st.checkbox("Reorder paths to reduce travel", value=True)
        st.markdown("---")
        threshold = st.number_input(
            "Stroke width threshold (mm) for cutting",
            min_value=0.01,
            max_value=5.0,
            value=0.3,
            step=0.05,
        )
        cut_color = st.color_picker("Cut stroke color", value="#FF0000")
        engrave_color = st.color_picker("Engrave fill color", value="#0000FF")

    if not uploaded_file:
        st.info("Upload an SVG file to begin optimization.")
        return

    svg_text = uploaded_file.getvalue().decode("utf-8")

    try:
        optimized_svg, report = optimize_svg(
            svg_text,
            precision=precision,
            threshold=threshold,
            cut_color=cut_color,
            engrave_color=engrave_color,
            do_remove_hidden=remove_hidden,
            do_round_numbers=round_numbers,
            do_reorder_paths=reorder_paths,
        )
    except ValueError as exc:
        st.error(str(exc))
        return

    col_preview, col_report = st.columns((1, 1))
    with col_preview:
        st.subheader("Optimized preview")
        st.markdown(
            f"<div class='svg-preview'>{optimized_svg}</div>", unsafe_allow_html=True
        )
        st.download_button(
            label="Download optimized SVG",
            data=optimized_svg,
            file_name=f"optimized_{uploaded_file.name}",
            mime="image/svg+xml",
        )

    with col_report:
        st.subheader("Optimization report")
        st.metric("Hidden elements removed", report.removed_hidden)
        st.metric("Numeric fields adjusted", report.precision_adjusted)
        st.metric("Paths reordered", report.sorted_paths)
        st.metric("Cut elements", report.cut_elements)
        st.metric("Engrave elements", report.engrave_elements)

        st.caption(
            "Cut elements are output with a stroke color and no fill, whereas engraving elements "
            "use a fill color only. Adjust the stroke width threshold in the sidebar to fine-tune "
            "classification."
        )


if __name__ == "__main__":
    main()
