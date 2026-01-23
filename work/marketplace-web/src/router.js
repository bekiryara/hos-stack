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

const routes = [
  { path: '/', component: CategoriesPage },
  { path: '/demo', component: DemoDashboardPage },
  { path: '/search/:categoryId?', component: ListingsSearchPage, props: true },
  { path: '/listing/:id', component: ListingDetailPage, props: true },
  { path: '/listing/:id/message', component: MessagingPage, props: true },
  { path: '/listing/create', component: CreateListingPage },
  { path: '/reservation/create', component: CreateReservationPage },
  { path: '/rental/create', component: CreateRentalPage },
  { path: '/account', component: AccountPortalPage },
];

export default createRouter({
  history: createWebHistory(),
  routes,
});

