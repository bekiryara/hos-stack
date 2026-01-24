import { createRouter, createWebHistory } from 'vue-router';
import CategoriesPage from './pages/CategoriesPage.vue';
import ListingsSearchPage from './pages/ListingsSearchPage.vue';
import ListingDetailPage from './pages/ListingDetailPage.vue';
import CreateListingPage from './pages/CreateListingPage.vue';
import CreateReservationPage from './pages/CreateReservationPage.vue';
import CreateRentalPage from './pages/CreateRentalPage.vue';
import AccountPortalPage from './pages/AccountPortalPage.vue';
import DemoDashboardPage from './pages/DemoDashboardPage.vue';
import MessagingPage from './pages/MessagingPage.vue';
import NeedDemoPage from './pages/NeedDemoPage.vue';
import AuthPortalPage from './pages/AuthPortalPage.vue';
import { isTokenPresent } from './lib/demoSession.js';

const routes = [
  { path: '/', component: CategoriesPage },
  { path: '/demo', component: DemoDashboardPage, meta: { requiresAuth: true } },
  { path: '/need-demo', component: NeedDemoPage },
  { path: '/search/:categoryId?', component: ListingsSearchPage, props: true },
  { path: '/listing/:id', component: ListingDetailPage, props: true },
  { path: '/listing/:id/message', component: MessagingPage, props: true, meta: { requiresAuth: true } },
  { path: '/listing/create', component: CreateListingPage, meta: { requiresAuth: true } },
  { path: '/reservation/create', component: CreateReservationPage, meta: { requiresAuth: true } },
  { path: '/rental/create', component: CreateRentalPage, meta: { requiresAuth: true } },
  { path: '/account', component: AccountPortalPage },
  { path: '/auth', component: AuthPortalPage },
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

// Router guard for auth-required routes (WP-58, WP-66)
router.beforeEach((to, from, next) => {
  if (to.matched.some(record => record.meta.requiresAuth)) {
    if (!isTokenPresent()) {
      // WP-66: Redirect to Auth Portal instead of NeedDemoPage
      next('/auth');
    } else {
      next();
    }
  } else {
    next();
  }
});

export default router;

