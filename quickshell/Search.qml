pragma Singleton

import Quickshell

// Ranked search shared by the menus. The query splits into tokens; every token has to match one of an
// item's fields (case-insensitively), and items sort by how well they matched. Per token, roughly:
// exact > prefix > start of a word > anywhere > fuzzy subsequence; hits in secondary fields count less.
// Ties keep the input order, so callers pass their items most used first.
Singleton {
    readonly property real secondaryWeight: 0.6

    // Start of a word: after a non-alphanumeric character, or a camelCase hump ("OpenJDK", "LibreOffice").
    function wordStart(text, i) {
        if (i === 0)
            return true;
        const prev = text[i - 1], cur = text[i];
        const isLetter = c => c.toLowerCase() !== c.toUpperCase();
        if (!isLetter(prev) && !/[0-9]/.test(prev))
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
    function scoreField(text, token, primary, opts) {
        const lower = text.toLowerCase();
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
        const tokens = query.trim().toLowerCase().split(/\s+/).filter(t => t);
        if (tokens.length === 0)
            return items;
        opts = opts ?? {};
        const scored = [];
        items.forEach((item, index) => {
            const f = fields(item);
            const texts = (Array.isArray(f) ? f : [f]).map(t => String(t ?? ""));
            let total = 0;
            for (const token of tokens) {
                let best = 0;
                texts.forEach((text, i) => {
                    if (text !== "")
                        best = Math.max(best, scoreField(text, token, i === 0, opts) * (i === 0 ? 1 : secondaryWeight));
                });
                if (best === 0)
                    return;
                total += best;
            }
            scored.push({
                item: item,
                score: total,
                index: index
            });
        });
        return scored.sort((a, b) => b.score - a.score || a.index - b.index).map(s => s.item);
    }
}
