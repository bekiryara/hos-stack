import { createRouter, createWebHistory } from 'vue-router';
import CategoriesPage from './pages/CategoriesPage.vue';
import ListingsSearchPage from './pages/ListingsSearchPage.vue';
import ListingDetailPage from './pages/ListingDetailPage.vue';
import CreateListingPage from './pages/CreateListingPage.vue';
import CreateReservationPage from './pages/CreateReservationPage.vue';
import CreateRentalPage from './pages/CreateRentalPage.vue';
import CreateOrderPage from './pages/CreateOrderPage.vue';
import AccountPortalPage from './pages/AccountPortalPage.vue';
import DemoDashboardPage from './pages/DemoDashboardPage.vue';
import MessagingPage from './pages/MessagingPage.vue';
import NeedDemoPage from './pages/NeedDemoPage.vue';
import AuthPortalPage from './pages/AuthPortalPage.vue';
import LoginPage from './pages/LoginPage.vue';
import RegisterPage from './pages/RegisterPage.vue';
import FirmRegisterPage from './pages/FirmRegisterPage.vue';
import { isLoggedIn, clearSession } from './lib/demoSession.js';
import { isDemoMode } from './lib/demoMode.js';

const routes = [
  { path: '/', component: CategoriesPage },
  { path: '/demo', component: DemoDashboardPage, meta: { requiresAuth: true } },
  { path: '/need-demo', component: NeedDemoPage },
  { path: '/search/:categoryId?', component: ListingsSearchPage, props: true },
  { path: '/listing/:id', component: ListingDetailPage, props: true },
  { path: '/listing/:id/message', component: MessagingPage, props: true, meta: { requiresAuth: true } },
  { path: '/listing/create', component: CreateListingPage, meta: { requiresAuth: true, requiresFirm: true } },
  { path: '/reservation/create', component: CreateReservationPage, meta: { requiresAuth: true } },
  { path: '/rental/create', component: CreateRentalPage, meta: { requiresAuth: true } },
  { path: '/order/create', component: CreateOrderPage, meta: { requiresAuth: true } },
  { path: '/account', component: AccountPortalPage, meta: { requiresAuth: true } },
  { path: '/firm/register', component: FirmRegisterPage, meta: { requiresAuth: true } },
  { path: '/auth', component: AuthPortalPage },
  { path: '/login', component: LoginPage },
  { path: '/register', component: RegisterPage },
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

// WP-68: Router guard for auth-required routes and firm-only routes
import { getActiveTenantId } from './lib/demoSession.js';

router.beforeEach((to, from, next) => {
  // WP-68: Guard demo dashboard route - redirect if not in demo mode
  if (to.path === '/demo') {
    if (!isDemoMode()) {
      // Not in demo mode, redirect to account
      next({ path: '/account' });
      return;
    }
  }
  
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
      // WP-68: Show friendly message - redirect to account or show message
      // For now, allow access but page will show friendly message
      next();
      return;
    }
  }
  
  next();
});

export default router;

