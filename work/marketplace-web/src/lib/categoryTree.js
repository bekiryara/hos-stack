/**
 * Category tree helpers (single source of truth for traversal)
 *
 * Goal: prevent drift across Stepper / Search / Detail / other UIs.
 * Tree shape assumed:
 *  - node: { id, slug, title?, children?: node[] }
 */

function safeArray(v) {
  return Array.isArray(v) ? v : [];
}

export function categoryLabel(node) {
  if (!node) return '';
  return String(node.title || node.slug || node.name || '');
}

export function isLeafCategory(node) {
  const children = safeArray(node && node.children);
  return children.length === 0;
}

/**
 * Flatten the tree into searchable rows with stable paths.
 * Returns: [{ id, slug, title, path, pathArray, isLeaf, node }]
 */
export function flattenCategoriesTree(categoriesTree) {
  const out = [];

  const walk = (nodes, path = []) => {
    safeArray(nodes).forEach((node) => {
      if (!node || node.id === null || node.id === undefined) return;
      const children = safeArray(node.children);
      const leaf = children.length === 0;
      const nextPath = [...path, categoryLabel(node)];

      out.push({
        id: node.id,
        slug: node.slug,
        title: node.title,
        path: nextPath.join(' > '),
        pathArray: nextPath,
        isLeaf: leaf,
        node,
      });

      if (!leaf) walk(children, nextPath);
    });
  };

  walk(categoriesTree);
  return out;
}

/**
 * For a target id, returns the ancestor id stack (excluding target),
 * suitable for navigationStack in the stepper.
 */
export function findCategoryAncestorPathIds(categoriesTree, targetId) {
  const id = targetId ? Number(targetId) : null;
  if (!id) return [];

  const findPath = (nodes, wantedId, path = []) => {
    for (const node of safeArray(nodes)) {
      if (!node) continue;
      if (Number(node.id) === wantedId) return path;
      const children = safeArray(node.children);
      if (children.length > 0) {
        const res = findPath(children, wantedId, [...path, Number(node.id)]);
        if (res) return res;
      }
    }
    return null;
  };

  return findPath(categoriesTree, id) || [];
}

export function getBreadcrumbsForPath(categoriesTree, pathIds) {
  const crumbs = [];
  let nodes = categoriesTree;
  for (const rawId of safeArray(pathIds)) {
    const id = Number(rawId);
    const found = safeArray(nodes).find((n) => n && Number(n.id) === id);
    if (!found) break;
    crumbs.push(found);
    nodes = safeArray(found.children);
  }
  return crumbs;
}

export function getChildrenAtPath(categoriesTree, pathIds) {
  let nodes = categoriesTree;
  for (const rawId of safeArray(pathIds)) {
    const id = Number(rawId);
    const found = safeArray(nodes).find((n) => n && Number(n.id) === id);
    if (!found) return [];
    nodes = safeArray(found.children);
  }
  return safeArray(nodes);
}

/**
 * Find a category node by id anywhere in the tree.
 * Returns the node (original object) or null.
 */
export function findCategoryById(categoriesTree, targetId) {
  const wanted = targetId !== null && targetId !== undefined ? Number(targetId) : null;
  if (!wanted) return null;

  const walk = (nodes) => {
    for (const node of safeArray(nodes)) {
      if (!node) continue;
      if (Number(node.id) === wanted) return node;
      const children = safeArray(node.children);
      if (children.length > 0) {
        const found = walk(children);
        if (found) return found;
      }
    }
    return null;
  };

  return walk(categoriesTree);
}

/**
 * Find a category node by canonical category id anywhere in the tree.
 * Menu trees may use path-based virtual ids while exposing the real DB id as
 * `canonical_category_id`. Canonical trees may only have `id`.
 */
export function findCategoryByCanonicalId(categoriesTree, targetId) {
  const wanted = targetId !== null && targetId !== undefined ? Number(targetId) : null;
  if (!wanted) return null;

  const walk = (nodes) => {
    for (const node of safeArray(nodes)) {
      if (!node) continue;
      const canonicalId = node.canonical_category_id !== null && node.canonical_category_id !== undefined
        ? Number(node.canonical_category_id)
        : null;
      if (Number.isFinite(canonicalId) && canonicalId === wanted) return node;
      if (!Number.isFinite(canonicalId) && Number(node.id) === wanted) return node;
      const children = safeArray(node.children);
      if (children.length > 0) {
        const found = walk(children);
        if (found) return found;
      }
    }
    return null;
  };

  return walk(categoriesTree);
}
