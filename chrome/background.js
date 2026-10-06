// Resolves EIP/ERC numbers to a title, description and upgrade status for the
// content script.
//
// Lookups run here rather than in the content script because page origins
// can't fetch these sites cross-origin; the extension's host permissions can.
//
// forkcast goes first: its index carries EIPs still sitting in a PR, which
// eips.ethereum.org doesn't list. eips.ethereum.org is the fallback, and also
// covers ERCs and anything forkcast doesn't track. Older EIPs predate the
// description field, so they come back with a title only. The upgrade status
// is forkcast's alone.

const FORKCAST_INDEX = "https://forkcast.org/api/eips.json";
const DAY_MS = 24 * 60 * 60 * 1000;
const INDEX_MAX_AGE_MS = DAY_MS;
const SITE_MAX_AGE_MS = 7 * DAY_MS;
/** Bumped whenever the stored index's shape changes, so an older one is refetched. */
const INDEX_SCHEMA = 2;

/**
 * "Scheduled for Glamsterdam (headliner) · Declined for Fusaka": the current
 * stage in each upgrade forkcast tracks the EIP for, newest upgrade first.
 * forkcast lists upgrades oldest first, and each history ends at the current stage.
 */
function upgradeStatus(relationships = []) {
  return relationships
    .filter((r) => r.statusHistory?.length)
    .map((r) => `${r.statusHistory.at(-1).status} for ${r.forkName}${r.isHeadliner ? " (headliner)" : ""}`)
    .reverse()
    .join(" · ");
}

/** forkcast's whole index is one file, so keep it in storage and refresh it daily. */
async function forkcastIndex() {
  const { forkcast } = await chrome.storage.local.get("forkcast");
  if (forkcast?.schema === INDEX_SCHEMA && Date.now() - forkcast.fetchedAt < INDEX_MAX_AGE_MS) {
    return forkcast.eips;
  }
  try {
    const res = await fetch(FORKCAST_INDEX);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    const eips = Object.fromEntries(
      data.eips.map((e) => [
        e.id,
        { title: e.title, description: e.description ?? "", status: upgradeStatus(e.forkRelationships) },
      ]),
    );
    await chrome.storage.local.set({ forkcast: { schema: INDEX_SCHEMA, fetchedAt: Date.now(), eips } });
    return eips;
  } catch (err) {
    console.warn("forkcast index fetch failed:", err);
    // A stale index still answers most numbers, as long as it has the current shape.
    return forkcast?.schema === INDEX_SCHEMA ? forkcast.eips : {};
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

/**
 * Title and description from the EIP's page, cached per EIP for a week.
 * Misses aren't cached, so a newly published EIP shows up at once.
 */
async function eipsSite(num) {
  const key = `eip:${num}`;
  const { [key]: cached } = await chrome.storage.local.get(key);
  if (cached && Date.now() - cached.fetchedAt < SITE_MAX_AGE_MS) return cached;
  try {
    const res = await fetch(`https://eips.ethereum.org/EIPS/eip-${num}`);
    if (!res.ok) return null;
    const html = await res.text();
    // The page's <title> is "EIP-N: Title" (or "ERC-N: ..." after the ERC redirect).
    const title = html.match(/<title>([^<]*)<\/title>/)?.[1];
    if (!title) return null;
    const description = html.match(/<meta name="description" content="([^"]*)"/)?.[1] ?? "";
    const entry = {
      title: decodeEntities(title.trim()),
      description: decodeEntities(description.trim()),
      url: res.url,
      fetchedAt: Date.now(),
    };
    await chrome.storage.local.set({ [key]: entry });
    return entry;
  } catch (err) {
    console.warn(`eips.ethereum.org lookup for ${num} failed:`, err);
    // Offline: a stale entry beats nothing.
    return cached ?? null;
  }
}

async function lookup(num) {
  const fromForkcast = (await forkcastIndex())[num];
  if (fromForkcast) {
    return { ...fromForkcast, url: `https://forkcast.org/eips/${num}`, source: "forkcast.org" };
  }
  const site = await eipsSite(num);
  if (site) {
    const { title, description, url } = site;
    return { title, description, status: "", url, source: "eips.ethereum.org" };
  }
  return { title: null };
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.type !== "eip-title") return;
  lookup(msg.num).then(sendResponse);
  // Keep the channel open for the async response.
  return true;
});
