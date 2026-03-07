import React from 'react';

const links = [
  { href: '/admin/dashboard', label: 'Pano' },
  { href: '/admin/worlds', label: 'Dunyalar' },
  { href: '/admin/categories', label: 'Kategoriler' },
  { href: '/admin/listings', label: 'Ilanlar' },
  { href: '/admin/users', label: 'Kullanicilar' },
  { href: '/admin/memberships', label: 'Uyelikler' },
  { href: '/admin/audit', label: 'Denetim' },
];

export function AdminSidebar() {
  const pathname = window.location.pathname;

  return (
    <nav aria-label="Admin navigation">
      <div className="card admin-sidebar-card">
        <div className="title">Yonetim Menusu</div>
        <ul className="admin-sidebar-list" style={{ margin: 0, paddingLeft: 0, listStyle: 'none' }}>
          {links.map((link) => (
            <li key={link.href}>
              <a
                href={link.href}
                className={pathname === link.href ? 'admin-nav-link active' : 'admin-nav-link'}
              >
                {link.label}
              </a>
            </li>
          ))}
        </ul>
      </div>
    </nav>
  );
}
