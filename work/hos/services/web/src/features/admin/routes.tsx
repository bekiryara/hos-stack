import React from 'react';
import { AdminControlCenterPage } from './pages/AdminControlCenterPage';
import { AuditPage } from './pages/AuditPage';
import { DashboardPage } from './pages/DashboardPage';
import { MembershipsPage } from './pages/MembershipsPage';
import { ListingsPage } from './pages/ListingsPage';
import { UsersPage } from './pages/UsersPage';
import { WorldsPage } from './pages/WorldsPage';
import { hasAdminToken } from './session';

const routeMap: Record<string, React.ReactElement> = {
  '/admin/control-center': <AdminControlCenterPage />,
  '/admin/dashboard': <DashboardPage />,
  '/admin/worlds': <WorldsPage />,
  '/admin/listings': <ListingsPage />,
  '/admin/users': <UsersPage />,
  '/admin/memberships': <MembershipsPage />,
  '/admin/audit': <AuditPage />,
};

export function isAdminRoutePath(pathname: string): boolean {
  return pathname.startsWith('/admin');
}

export function resolveAdminRoute(pathname: string): React.ReactElement | null {
  if (!isAdminRoutePath(pathname)) return null;

  // /admin is the login/control-center entry. If already authenticated, land on dashboard.
  if (pathname === '/admin') {
    return hasAdminToken() ? <DashboardPage /> : <AdminControlCenterPage />;
  }

  // All other admin routes are protected behind a token.
  const target = routeMap[pathname];
  if (!target) return <AdminControlCenterPage />;
  return hasAdminToken() ? target : <AdminControlCenterPage />;
}
