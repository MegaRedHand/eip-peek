// Resolves EIP/ERC numbers to titles for the content script.
//
// Lookups run here rather than in the content script because page origins
// can't fetch these sites cross-origin; the extension's host permissions can.
//
// forkcast goes first: its index carries EIPs still sitting in a PR, which
// eips.ethereum.org doesn't list. eips.ethereum.org is the fallback, and also
// covers ERCs and anything forkcast doesn't track.

const FORKCAST_INDEX = "https://forkcast.org/api/eips.json";
const INDEX_MAX_AGE_MS = 24 * 60 * 60 * 1000;

/** forkcast's whole index is one file, so keep it in storage and refresh it daily. */
async function forkcastTitles() {
  const { forkcast } = await chrome.storage.local.get("forkcast");
  if (forkcast && Date.now() - forkcast.fetchedAt < INDEX_MAX_AGE_MS) {
    return forkcast.titles;
  }
  try {
    const res = await fetch(FORKCAST_INDEX);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const { eips } = await res.json();
    const titles = Object.fromEntries(eips.map((e) => [e.id, e.title]));
    await chrome.storage.local.set({ forkcast: { fetchedAt: Date.now(), titles } });
    return titles;
  } catch (err) {
    console.warn("forkcast index fetch failed:", err);
    // A stale index still answers most numbers.
    return forkcast?.titles ?? {};
  }
}

function decodeEntities(s) {
  return s
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");
}

/** The page's <title> is "EIP-N: Title" (or "ERC-N: ..." after the ERC redirect). */
async function eipsSiteTitle(num) {
  try {
    const res = await fetch(`https://eips.ethereum.org/EIPS/eip-${num}`);
    if (!res.ok) return null;
    const match = (await res.text()).match(/<title>([^<]*)<\/title>/);
    return match ? { title: decodeEntities(match[1].trim()), url: res.url } : null;
  } catch (err) {
    console.warn(`eips.ethereum.org lookup for ${num} failed:`, err);
    return null;
  }
}

async function lookup(num) {
  const title = (await forkcastTitles())[num];
  if (title) {
    return { title, url: `https://forkcast.org/eips/${num}`, source: "forkcast.org" };
  }
  const site = await eipsSiteTitle(num);
  if (site) return { ...site, source: "eips.ethereum.org" };
  return { title: null };
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.type !== "eip-title") return;
  lookup(msg.num).then(sendResponse);
  // Keep the channel open for the async response.
  return true;
});
