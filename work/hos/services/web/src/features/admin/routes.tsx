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

export function resolveAdminRoute(pathname: string): React.ReactElement | null {
  if (!isAdminRoutePath(pathname)) return null;
  if (pathname === '/ui/admin/dashboard') return <DashboardPage />;
  if (pathname === '/ui/admin/tenants') return <TenantsPage />;
  if (pathname === '/ui/admin/users') return <UsersPage />;
  if (pathname === '/ui/admin/memberships') return <MembershipsPage />;
  if (pathname === '/ui/admin/audit') return <AuditPage />;
  return <AdminControlCenterPage />;
}
