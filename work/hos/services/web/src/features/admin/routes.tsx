import React from 'react';
import { AdminControlCenterPage } from './pages/AdminControlCenterPage';
import { AuditPage } from './pages/AuditPage';
import { DashboardPage } from './pages/DashboardPage';
import { MembershipsPage } from './pages/MembershipsPage';
import { TenantsPage } from './pages/TenantsPage';
import { UsersPage } from './pages/UsersPage';

export function isAdminRoutePath(pathname: string): boolean {
  return pathname.startsWith('/ui/admin') || pathname.startsWith('/admin');
}

function normalizeAdminPath(pathname: string): string {
  if (pathname.startsWith('/ui/admin')) {
    return pathname.replace('/ui/admin', '/admin');
  }
  return pathname;
}

export function resolveAdminRoute(pathname: string): React.ReactElement | null {
  if (!isAdminRoutePath(pathname)) return null;
  const path = normalizeAdminPath(pathname);
  if (path === '/admin/dashboard') return <DashboardPage />;
  if (path === '/admin/tenants') return <TenantsPage />;
  if (path === '/admin/users') return <UsersPage />;
  if (path === '/admin/memberships') return <MembershipsPage />;
  if (path === '/admin/audit') return <AuditPage />;
  return <AdminControlCenterPage />;
}
