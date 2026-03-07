import React from 'react';
import { AdminSidebar } from './AdminSidebar';
import { clearAdminSession, getAdminEmail, hasAdminToken } from '../session';

type AdminLayoutProps = {
  title: string;
  children: React.ReactNode;
};

export function AdminLayout({ title, children }: AdminLayoutProps) {
  const loggedIn = hasAdminToken();
  const adminEmail = getAdminEmail();
  const pathname = window.location.pathname;
  const isControlCenterRoute = pathname === '/admin' || pathname === '/admin/control-center';
  const showSidebar = loggedIn && !isControlCenterRoute;

  function handleLogout() {
    clearAdminSession();
    window.location.href = '/admin';
  }

  return (
    <div className="page" data-marker="hos-admin-layout">
      <header className="top admin-top">
        <div className="brand">
          H-OS Yonetim <span style={{ fontSize: '0.7rem', color: '#93a0b8', fontWeight: 'normal' }}>(DEV)</span>
        </div>
        <div className="actions">
          {loggedIn ? <span style={{ color: '#9ca3af', fontSize: '0.85rem' }}>Oturum: {adminEmail || 'admin'}</span> : null}
          <a href="/" style={{ marginRight: '0.75rem' }}>
            Ana Sayfa
          </a>
          {loggedIn ? (
            <button onClick={handleLogout} style={{ marginRight: '0.25rem' }}>
              Cikis Yap
            </button>
          ) : null}
        </div>
      </header>

      <main className="main admin-main" style={{ maxWidth: '1400px' }}>
        <h1 className="admin-page-title">{title}</h1>
        <div
          className="admin-grid"
          style={{
            display: 'grid',
            gridTemplateColumns: showSidebar ? '260px minmax(0, 1fr)' : 'minmax(0, 1fr)',
            gap: '1rem',
          }}
        >
          {showSidebar ? <AdminSidebar /> : null}
          <section className="admin-content">{children}</section>
        </div>
      </main>
    </div>
  );
}
