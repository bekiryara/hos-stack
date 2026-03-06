import React from 'react';
import { AdminControlCenterPage } from './pages/AdminControlCenterPage';
import { AuditPage } from './pages/AuditPage';
import { DashboardPage } from './pages/DashboardPage';
import { MembershipsPage } from './pages/MembershipsPage';
import { TenantsPage } from './pages/TenantsPage';
import { UsersPage } from './pages/UsersPage';

export function isAdminRoutePath(pathname: string): boolean {
  return pathname.startsWith('/admin');
}

export function resolveAdminRoute(pathname: string): React.ReactElement | null {
  if (!isAdminRoutePath(pathname)) return null;
  if (pathname === '/admin/dashboard') return <DashboardPage />;
  if (pathname === '/admin/tenants') return <TenantsPage />;
  if (pathname === '/admin/users') return <UsersPage />;
  if (pathname === '/admin/memberships') return <MembershipsPage />;
  if (pathname === '/admin/audit') return <AuditPage />;
  return <AdminControlCenterPage />;
}
