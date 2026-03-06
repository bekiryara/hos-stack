import React from 'react';

const links = [
  { href: '/ui/admin/control-center', label: 'Control Center' },
  { href: '/ui/admin/dashboard', label: 'Dashboard' },
  { href: '/ui/admin/tenants', label: 'Tenants' },
  { href: '/ui/admin/users', label: 'Users' },
  { href: '/ui/admin/memberships', label: 'Memberships' },
  { href: '/ui/admin/audit', label: 'Audit' },
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
