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
          H-OS Admin <span style={{ fontSize: '0.7rem', color: '#ff6b6b', fontWeight: 'normal' }}>(DEV ONLY)</span>
        </div>
        <div className="actions">
          <a href="/" style={{ marginRight: '0.75rem' }}>
            Home
          </a>
          <a href="/api/v1/health" target="_blank" rel="noreferrer">
            /api/v1/health
          </a>
        </div>
      </header>

      <main className="main">
        <h1>{title}</h1>
        <div style={{ display: 'grid', gridTemplateColumns: '220px 1fr', gap: '1rem' }}>
          <AdminSidebar />
          <section>{children}</section>
        </div>
      </main>
    </div>
  );
}
