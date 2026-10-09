"""Optional theme colours for the page: a Material-You palette as JSON ({"primary": "#…", …}, the shape
matugen writes), given with --theme or $KITTY_CAM_THEME. Without one, the page uses its own colours."""
import json

# Offered as swatches beside the page's colour pickers.
PALETTE = ["primary", "secondary", "tertiary", "inverse_primary", "primary_container", "secondary_container",
           "tertiary_container", "on_primary_container", "on_secondary_container", "on_tertiary_container",
           "surface_container_highest", "on_surface", "outline", "error"]


def load(path):
    """{cat, background, fill, palette} for the page, or {} (no theme file, or not readable)."""
    if not path:
        return {}
    try:
        c = json.loads(path.read_text())
        return {"cat": c["primary"], "background": c["surface"], "fill": c["primary_container"],
                "palette": {role: c[role] for role in PALETTE if role in c}}
    except (OSError, ValueError, KeyError, TypeError):
        return {}
