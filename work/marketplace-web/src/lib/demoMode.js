// WP-68: Demo Mode Helper
// Demo mode is ON if either:
//   1) URL query includes ?demo=1 (preferred)
//   2) localStorage key demo_mode=1 (optional fallback)

const DEMO_MODE_KEY = 'demo_mode';

/**
 * Check if demo mode is currently active
 * @returns {boolean} True if demo mode is ON
 */
export function isDemoMode() {
  // Check URL query parameter first (preferred)
  if (typeof window !== 'undefined') {
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('demo') === '1') {
      return true;
    }
    
    // Fallback: check localStorage
    const stored = localStorage.getItem(DEMO_MODE_KEY);
    if (stored === '1') {
      return true;
    }
  }
  
  return false;
}

/**
 * Set demo mode ON or OFF
 * @param {boolean} on - True to enable demo mode, false to disable
 * @param {boolean} updateUrl - If true, update URL with ?demo=1 or remove it
 */
export function setDemoMode(on, updateUrl = false) {
  if (typeof window === 'undefined') return;
  
  if (on) {
    localStorage.setItem(DEMO_MODE_KEY, '1');
    if (updateUrl) {
      const url = new URL(window.location.href);
      url.searchParams.set('demo', '1');
      window.history.replaceState({}, '', url);
    }
  } else {
    localStorage.removeItem(DEMO_MODE_KEY);
    if (updateUrl) {
      const url = new URL(window.location.href);
      url.searchParams.delete('demo');
      window.history.replaceState({}, '', url);
    }
  }
}

/**
 * Get demo mode state from URL or localStorage
 * This is a convenience function that can be used in computed properties
 */
export function getDemoMode() {
  return isDemoMode();
}

