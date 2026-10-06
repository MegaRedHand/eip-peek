// Double-click (or select) an EIP/ERC number to see its title and description
// in a small popup.
//
// A bare number needs 4-5 digits, so double-clicking ordinary numbers stays
// quiet. Right after "EIP-"/"ERC-" any length works (EIP-20, ERC-721).

const BARE = /^\d{4,5}$/;
const PREFIXED = /^(?:EIP|ERC)[-\s]?(\d{1,5})$/i;
const PREFIX_BEFORE = /(?:EIP|ERC)[-\s]?$/i;

const STYLE = `
  .box {
    font: 13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    max-width: 420px;
    padding: 8px 10px;
    border-radius: 8px;
    background: #fff;
    color: #1d1d1f;
    border: 1px solid rgba(0, 0, 0, 0.12);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.18);
  }
  a { color: inherit; font-weight: 600; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .desc { display: block; margin-top: 3px; color: #3a3a3c; }
  .src { display: block; margin-top: 3px; font-size: 11px; color: #8e8e93; }
  @media (prefers-color-scheme: dark) {
    .box { background: #2c2c2e; color: #f5f5f7; border-color: rgba(255, 255, 255, 0.14); }
    .desc { color: #d1d1d6; }
    .src { color: #98989d; }
  }
`;

// A constructed stylesheet, not a <style> element, so a page's CSP can't block it.
const sheet = new CSSStyleSheet();
sheet.replaceSync(STYLE);

let host = null;

/** The EIP number the selection names, or null. */
function selectedNumber(sel) {
  if (sel.rangeCount === 0) return null;
  const text = sel.toString().trim();

  const prefixed = text.match(PREFIXED);
  if (prefixed) return Number(prefixed[1]);
  if (BARE.test(text)) return Number(text);
  if (!/^\d{1,5}$/.test(text)) return null;

  // Double-clicking "EIP-20" selects only "20", so check the text just before
  // it. The prefix may sit in a neighboring node (e.g. "EIP-<a>20</a>"), hence
  // starting from the grandparent rather than the selected text node.
  const range = sel.getRangeAt(0);
  const node = range.startContainer;
  const scope = node.parentNode?.parentNode ?? node.parentNode ?? node;
  const before = document.createRange();
  before.setStart(scope, 0);
  before.setEnd(node, range.startOffset);
  return PREFIX_BEFORE.test(before.toString().slice(-5)) ? Number(text) : null;
}

function hidePopup() {
  host?.remove();
  host = null;
}

/** Shows a popup by the selection and fills it in once the lookup returns. */
async function showPopup(rect, num) {
  hidePopup();
  host = document.createElement("eip-title-popup");
  const root = host.attachShadow({ mode: "open" });
  root.adoptedStyleSheets = [sheet];
  const box = document.createElement("div");
  box.className = "box";
  box.textContent = `EIP-${num}: looking up…`;
  root.append(box);

  // Below the selection, or above it when too close to the bottom edge.
  const left = Math.max(8, Math.min(rect.left, window.innerWidth - 436));
  const vertical =
    rect.bottom + 90 > window.innerHeight
      ? `bottom:${window.innerHeight - rect.top + 6}px`
      : `top:${rect.bottom + 6}px`;
  host.style.cssText = `position:fixed;z-index:2147483647;left:${left}px;${vertical}`;
  document.documentElement.append(host);

  let result;
  try {
    result = await chrome.runtime.sendMessage({ type: "eip-title", num });
  } catch (err) {
    // Happens when the extension was reloaded under an open tab.
    box.textContent = `EIP-${num}: lookup failed (${err.message}). Reload the page.`;
    return;
  }

  // The popup may have been replaced meanwhile; then this box is detached and
  // updating it is harmless.
  if (!result?.title) {
    box.textContent = `EIP-${num}: not found on forkcast.org or eips.ethereum.org`;
    return;
  }
  const link = document.createElement("a");
  link.href = result.url;
  link.target = "_blank";
  link.rel = "noopener noreferrer";
  link.textContent = result.title;
  const parts = [link];
  if (result.description) {
    const desc = document.createElement("span");
    desc.className = "desc";
    desc.textContent = result.description;
    parts.push(desc);
  }
  const src = document.createElement("span");
  src.className = "src";
  src.textContent = result.source;
  parts.push(src);
  box.replaceChildren(...parts);
}

document.addEventListener("mouseup", (event) => {
  // Clicking the popup's own link must not rebuild the popup under the cursor.
  if (host && event.target === host) return;
  // Read the selection after the browser finishes handling the click, since a
  // click inside an existing selection only clears it at that point.
  setTimeout(() => {
    const sel = window.getSelection();
    const num = selectedNumber(sel);
    if (num === null) return;
    showPopup(sel.getRangeAt(0).getBoundingClientRect(), num);
  });
});

document.addEventListener("mousedown", (event) => {
  if (host && event.target !== host) hidePopup();
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") hidePopup();
});
document.addEventListener("scroll", hidePopup, { capture: true, passive: true });
