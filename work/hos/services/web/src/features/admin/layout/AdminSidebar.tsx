import React from 'react';

const links = [
  { href: '/admin', label: 'Control Center' },
  { href: '/admin/dashboard', label: 'Dashboard' },
  { href: '/admin/tenants', label: 'Tenants' },
  { href: '/admin/users', label: 'Users' },
  { href: '/admin/memberships', label: 'Memberships' },
  { href: '/admin/audit', label: 'Audit' },
];

export function AdminSidebar() {
  return (
    <nav aria-label="Admin navigation">
      <div className="card">
        <div className="title">Admin</div>
        <ul style={{ margin: 0, paddingLeft: '1rem' }}>
          {links.map((link) => (
            <li key={link.href} style={{ marginBottom: '0.35rem' }}>
              <a href={link.href}>{link.label}</a>
            </li>
          ))}
        </ul>
      </div>
    </nav>
  );
}
