import React from 'react';

const links = [
  { href: '/admin', label: 'Kontrol Merkezi' },
  { href: '/admin/dashboard', label: 'Pano' },
  { href: '/admin/users', label: 'Kullanicilar' },
  { href: '/admin/audit', label: 'Denetim' },
];

export function AdminSidebar() {
  return (
    <nav aria-label="Admin navigation">
      <div className="card">
        <div className="title">Yonetim Menusu</div>
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
