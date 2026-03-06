import React from 'react';
import { AdminControlCenterPage } from './pages/AdminControlCenterPage';
import { AuditPage } from './pages/AuditPage';
import { DashboardPage } from './pages/DashboardPage';
import { MembershipsPage } from './pages/MembershipsPage';
import { UsersPage } from './pages/UsersPage';

const routeMap: Record<string, React.ReactElement> = {
  '/admin/dashboard': <DashboardPage />,
  '/admin/users': <UsersPage />,
  '/admin/memberships': <MembershipsPage />,
  '/admin/audit': <AuditPage />,
};

export function isAdminRoutePath(pathname: string): boolean {
  return pathname.startsWith('/admin');
}

export function resolveAdminRoute(pathname: string): React.ReactElement | null {
  if (!isAdminRoutePath(pathname)) return null;
  return routeMap[pathname] ?? <AdminControlCenterPage />;
}
