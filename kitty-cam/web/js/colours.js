// The Colours card: lines, fill and background, each with a free picker. The theme (kitty-cam --theme, if
// given) supplies the defaults and a palette of swatches; a colour picked here wins until "theme colours".
import { colors } from "./render.js";
import { $, store } from "./util.js";

let theme = null; // {cat, background, fill} from the theme, once loaded

function show() {
  $("c-cat").value = colors.cat;
  $("c-bg").value = colors.background;
  $("c-fill").value = colors.fill;
  for (const key of ["cat", "fill"])
    for (const b of $("sw-" + key).children) b.classList.toggle("on", b.dataset.color.toLowerCase() === colors[key].toLowerCase());
}

function pick(key, value) {
  colors[key] = value;
  store.set("colors", { cat: colors.cat, background: colors.background, fill: colors.fill });
  show();
}

function swatches(key, palette) {
  return Object.entries(palette).map(([role, hex]) => {
    const b = document.createElement("button");
    b.style.background = hex;
    b.dataset.color = hex;
    b.title = `${role.replace(/_/g, " ")} (${hex})`;
    b.setAttribute("aria-label", b.title);
    b.onclick = () => pick(key, hex);
    return b;
  });
}

export function initColours() {
  for (const [id, key] of [["c-cat", "cat"], ["c-bg", "background"], ["c-fill", "fill"]])
    $(id).oninput = e => pick(key, e.target.value);
  $("c-reset").onclick = () => { store.set("colors", null); Object.assign(colors, theme || {}); show(); };
  show();
  fetch("/theme").then(r => r.json()).then(t => {
    theme = { cat: t.cat || colors.cat, background: t.background || colors.background, fill: t.fill || colors.fill };
    for (const key of ["cat", "fill"]) $("sw-" + key).replaceChildren(...swatches(key, t.palette || {}));
    Object.assign(colors, theme, store.get("colors", null) || {});
    show();
  }).catch(() => { Object.assign(colors, store.get("colors", null) || {}); show(); });
}
