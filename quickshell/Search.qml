pragma Singleton

import Quickshell

// Ranked search shared by the menus. The query splits into tokens; every token has to match one of an
// item's fields (case-insensitively), and items sort by how well they matched. Per token, roughly:
// exact > prefix > start of a word > anywhere > fuzzy subsequence; hits in secondary fields count less.
// Ties keep the input order, so callers pass their items most used first.
Singleton {
    readonly property real secondaryWeight: 0.6

    // Per-keystroke cache for the items last ranked (the menus rank 2k–11k items on every key):
    // each item's fields, as {texts, lowers}, are built once, and the indices the last query matched are kept,
    // because a query that only extends the last one ("he" → "hea", "he" → "he a") can only match a subset of them.
    property var cacheItems: null
    property var cacheFields: null
    property string cacheOpts: ""
    property var prepared: []
    property string lastQuery: ""
    property var lastMatches: [] // indices into cacheItems, ascending

    function isLetter(c) {
        return c.toLowerCase() !== c.toUpperCase();
    }

    // Start of a word: after a non-alphanumeric character, or a camelCase hump ("OpenJDK", "LibreOffice").
    // ASCII is decided on char codes; anything else falls back to case mapping.
    function wordStart(text, i) {
        if (i === 0)
            return true;
        const p = text.charCodeAt(i - 1);
        if (p < 128) {
            const lowerPrev = p >= 97 && p <= 122;
            if (!lowerPrev && !(p >= 65 && p <= 90) && !(p >= 48 && p <= 57))
                return true;
            if (!lowerPrev)
                return false;
            const c = text.charCodeAt(i);
            return c < 128 ? c >= 65 && c <= 90 : text[i] !== text[i].toLowerCase();
        }
        const prev = text[i - 1], cur = text[i];
        if (!isLetter(prev))
            return true;
        return prev !== prev.toUpperCase() && cur !== cur.toLowerCase();
    }

    // Token characters in order, the first on a word start ("ffx" → Firefox, "vsc" → Visual Studio Code).
    // Scores 20–50 by how many characters land on word starts or right after the previous one.
    function fuzzyScore(text, lower, token) {
        let start = -1;
        for (let i = lower.indexOf(token[0]); i >= 0; i = lower.indexOf(token[0], i + 1)) {
            if (wordStart(text, i)) {
                start = i;
                break;
            }
        }
        if (start < 0)
            return 0;
        let good = 1, prev = start;
        for (let k = 1; k < token.length; k++) {
            const i = lower.indexOf(token[k], prev + 1);
            if (i < 0)
                return 0;
            if (i === prev + 1 || wordStart(text, i))
                good++;
            prev = i;
        }
        return 20 + 30 * good / token.length;
    }

    // opts.fuzzy: the primary field may also match as a subsequence.
    // opts.anywhere: secondary fields may match mid-word (otherwise only at word starts).
    function scoreField(text, lower, token, primary, opts) {
        if (lower === token)
            return 100;
        if (lower.startsWith(token))
            return 90;
        let mid = false;
        for (let i = lower.indexOf(token); i >= 0; i = lower.indexOf(token, i + 1)) {
            if (wordStart(text, i))
                return 80;
            mid = true;
        }
        if (mid && (primary || opts.anywhere))
            return 60;
        return primary && opts.fuzzy ? fuzzyScore(text, lower, token) : 0;
    }

    // fields(item) → a string or an array of strings, primary field first. Returns the matching items, best first.
    function rank(items, query, fields, opts) {
        opts = opts ?? {};
        const optsKey = JSON.stringify(opts);
        if (items !== cacheItems || fields !== cacheFields || optsKey !== cacheOpts) {
            prepared = items.map(item => {
                const f = fields(item);
                const texts = (Array.isArray(f) ? f : [f]).map(t => String(t ?? ""));
                return {
                    texts: texts,
                    lowers: texts.map(t => t.toLowerCase())
                };
            });
            cacheItems = items;
            cacheFields = fields;
            cacheOpts = optsKey;
            lastQuery = "";
        }

        const q = query.replace(/^\s+/, "").toLowerCase();
        const tokens = q.split(/\s+/).filter(t => t);
        if (tokens.length === 0) {
            lastQuery = "";
            return items;
        }
        const narrow = lastQuery !== "" && q.startsWith(lastQuery);
        const candidates = narrow ? lastMatches : null;
        const count = narrow ? candidates.length : items.length;

        // QML properties are read once into locals, and matches are kept as indices plus a score per index:
        // the loop runs up to ~11k times per key, and property reads and per-match objects dominated it.
        const prep = prepared, weight = secondaryWeight;
        const scores = {};
        const matches = [];
        for (let n = 0; n < count; n++) {
            const index = narrow ? candidates[n] : n;
            const entry = prep[index];
            const texts = entry.texts, lowers = entry.lowers;
            let total = 0;
            for (let t = 0; t < tokens.length; t++) {
                let best = 0;
                for (let i = 0; i < texts.length; i++) {
                    if (texts[i] !== "")
                        best = Math.max(best, scoreField(texts[i], lowers[i], tokens[t], i === 0, opts) * (i === 0 ? 1 : weight));
                }
                if (best === 0) {
                    total = 0;
                    break;
                }
                total += best;
            }
            if (total === 0)
                continue;
            matches.push(index);
            scores[index] = total;
        }
        lastQuery = q;
        lastMatches = matches;
        return matches.slice().sort((a, b) => scores[b] - scores[a] || a - b).map(i => items[i]);
    }
}
