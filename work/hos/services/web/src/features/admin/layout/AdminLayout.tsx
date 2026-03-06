import React from 'react';
import { AdminSidebar } from './AdminSidebar';

type AdminLayoutProps = {
  title: string;
  children: React.ReactNode;
};

export function AdminLayout({ title, children }: AdminLayoutProps) {
  return (
    <div className="page" data-marker="hos-admin-layout">
      <header className="top">
        <div className="brand">
          H-OS Yonetim <span style={{ fontSize: '0.7rem', color: '#ff6b6b', fontWeight: 'normal' }}>(DEV)</span>
        </div>
        <div className="actions">
          <a href="/" style={{ marginRight: '0.75rem' }}>
            Ana Sayfa
          </a>
        </div>
      </header>

      <main className="main" style={{ maxWidth: '1400px' }}>
        <h1>{title}</h1>
        <div style={{ display: 'grid', gridTemplateColumns: '260px minmax(0, 1fr)', gap: '1rem' }}>
          <AdminSidebar />
          <section>{children}</section>
        </div>
      </main>
    </div>
  );
}
