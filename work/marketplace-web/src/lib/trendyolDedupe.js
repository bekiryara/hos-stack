/**
 * Deterministic dedupe for Trendyol gendered variants in the canonical categories tree.
 *
 * Problem:
 * - DB can contain multiple active nodes for the same WC:
 *   - service-product-ty-c82   (neutral)
 *   - service-product-g1-ty-c82 (female)
 *   - service-product-g2-ty-c82 (male)
 * - In canonical (DB) tree, these appear as duplicates in UI.
 *
 * Policy (deterministic):
 * - Group by WC (the trailing -ty-c<WC>)
 * - Prefer neutral (gen=0), else lower gen (g1 over g2), else keep first seen.
 * - Merge children sets to avoid losing subtrees when neutral exists but children live under g1/g2.
 *
 * IMPORTANT:
 * - Do NOT apply this to view=menu (menu tree uses path-based node identities).
 */

function safeArray(v) {
  return Array.isArray(v) ? v : [];
}

function parseTrendyolSlugVariant(slug) {
  const s = String(slug || '').trim();
  if (!s) return null;
  const m = s.match(/-ty-c(\d+)$/);
  if (!m) return null;
  const wc = String(m[1]);
  const gm = s.match(/-g(\d+)-ty-c\d+$/);
  const gen = gm ? Number(gm[1]) : 0;
  return { wc, gen: Number.isFinite(gen) ? gen : 0 };
}

function variantPriority(v) {
  // Lower is better.
  if (!v) return 9999;
  if (v.gen === 0) return 0;
  if (v.gen > 0) return v.gen; // g1 < g2 < g3...
  return 9999;
}

function mergeSelectableForCreate(a, b) {
  const av = typeof a?.selectable_for_create === 'boolean' ? a.selectable_for_create : null;
  const bv = typeof b?.selectable_for_create === 'boolean' ? b.selectable_for_create : null;
  if (av === null) return bv;
  if (bv === null) return av;
  return Boolean(av || bv);
}

export function dedupeTrendyolWcVariants(tree) {
  const walk = (nodes) => {
    const out = [];
    const idxByWc = new Map(); // wc -> out index

    for (const raw of safeArray(nodes)) {
      if (!raw) continue;

      const children = walk(raw.children);
      const node = { ...raw, children };

      const v = parseTrendyolSlugVariant(node.slug);
      if (!v) {
        out.push(node);
        continue;
      }

      const wc = v.wc;
      if (!idxByWc.has(wc)) {
        idxByWc.set(wc, out.length);
        out.push(node);
        continue;
      }

      const idx = idxByWc.get(wc);
      const cur = out[idx];
      const curV = parseTrendyolSlugVariant(cur.slug) || { wc, gen: 9999 };

      const aBetter = variantPriority(curV) <= variantPriority(v);
      const best = aBetter ? cur : node;
      const other = aBetter ? node : cur;

      const mergedChildren = walk([...(safeArray(best.children)), ...(safeArray(other.children))]);
      const mergedSelectable = mergeSelectableForCreate(best, other);

      out[idx] = {
        ...best,
        children: mergedChildren,
        ...(typeof mergedSelectable === 'boolean' ? { selectable_for_create: mergedSelectable } : null),
      };
    }

    return out;
  };

  return walk(tree);
}

