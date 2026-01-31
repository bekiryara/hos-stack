import { createRouter, createWebHistory } from 'vue-router';
import CategoriesPage from './pages/CategoriesPage.vue';
import ListingsSearchPage from './pages/ListingsSearchPage.vue';
import ListingDetailPage from './pages/ListingDetailPage.vue';
import CreateListingPage from './pages/CreateListingPage.vue';
import CreateReservationPage from './pages/CreateReservationPage.vue';
import CreateRentalPage from './pages/CreateRentalPage.vue';
import CreateOrderPage from './pages/CreateOrderPage.vue';
import AccountPortalPage from './pages/AccountPortalPage.vue';
import MessagingPage from './pages/MessagingPage.vue';
import LoginPage from './pages/LoginPage.vue';
import RegisterPage from './pages/RegisterPage.vue';
import FirmRegisterPage from './pages/FirmRegisterPage.vue';
import FirmPortalPage from './pages/FirmPortalPage.vue';
import { isLoggedIn } from './lib/session.js';

const routes = [
  { path: '/', component: CategoriesPage },
  { path: '/search/:categoryId?', component: ListingsSearchPage, props: true },
  { path: '/listing/:id', component: ListingDetailPage, props: true },
  { path: '/listing/:id/message', component: MessagingPage, props: true, meta: { requiresAuth: true } },
  { path: '/listing/create', component: CreateListingPage, meta: { requiresAuth: true, requiresFirm: true } },
  { path: '/reservation/create', component: CreateReservationPage, meta: { requiresAuth: true } },
  { path: '/rental/create', component: CreateRentalPage, meta: { requiresAuth: true } },
  { path: '/order/create', component: CreateOrderPage, meta: { requiresAuth: true } },
  { path: '/account', component: AccountPortalPage, meta: { requiresAuth: true } },
  { path: '/account/orders/:id', component: OrderDetailPage, props: true, meta: { requiresAuth: true } },
  { path: '/account/rentals/:id', component: RentalDetailPage, props: true, meta: { requiresAuth: true } },
  { path: '/account/reservations/:id', component: ReservationDetailPage, props: true, meta: { requiresAuth: true } },
  { path: '/firm', component: FirmPortalPage, meta: { requiresAuth: true, requiresFirm: true } },
  { path: '/firm/register', component: FirmRegisterPage, meta: { requiresAuth: true } },
  { path: '/auth', redirect: '/login' },
  { path: '/login', component: LoginPage },
  { path: '/register', component: RegisterPage },
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

// WP-68: Router guard for auth-required routes and firm-only routes
import { getActiveTenantId } from './lib/session.js';

// Global 401 behavior: api/client.js clears session and emits `hos:session-expired`.
// Keep redirect logic centralized here (single behavior across pages).
if (typeof window !== 'undefined') {
  window.addEventListener('hos:session-expired', () => {
    // Avoid redirect loops
    const current = router.currentRoute?.value;
    if (current && current.path === '/login') return;
    router.push({ path: '/login', query: { reason: 'expired' } }).catch(() => {});
  });
}

router.beforeEach((to, from, next) => {
  // Single auth entry
  
  // Check auth-required routes
  if (to.matched.some(record => record.meta.requiresAuth)) {
    if (!isLoggedIn()) {
      // WP-68: Redirect to Login page with reason
      next({ path: '/login', query: { reason: 'expired' } });
      return;
    }
  }
  
  // WP-68: Check firm-only routes (require active tenant)
  if (to.matched.some(record => record.meta.requiresFirm)) {
    if (!isLoggedIn()) {
      next({ path: '/login', query: { reason: 'expired' } });
      return;
    }
    const activeTenantId = getActiveTenantId();
    if (!activeTenantId) {
      // Firm-only route: require an active firm (derived from memberships via /account)
      next({ path: '/account', query: { reason: 'firm_required' } });
      return;
    }
  }
  
  next();
});

export default router;

