# H-OS Stack Documentation

**Welcome to the H-OS Stack documentation!**

This is a full-stack marketplace platform built with Laravel (backend), Vue.js (frontend), and Docker (infrastructure).

---

## Quick Navigation

### For Developers
- **[Code Index](CODE_INDEX.html)** - Complete codebase navigation guide
- **[Architecture](ARCHITECTURE.html)** - System architecture overview
- **[Specification](SPEC.html)** - Technical specification
- **[Getting Started](START_HERE.html)** - Onboarding guide

### For AI/ChatGPT
- **[Code Index](CODE_INDEX.html)** - Start here to understand the codebase structure
- **[API Routes](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/routes/api.php)** - All backend endpoints
- **[Frontend Components](https://github.com/bekiryara/hos-stack/tree/main/work/marketplace-web/src)** - Vue.js components

---

## System Overview

### Services

1. **H-OS API** (`hos-api`)
   - Node.js service
   - Authentication and authorization
   - OIDC provider

2. **Pazar API** (`pazar-app`)
   - Laravel application
   - Marketplace backend
   - RESTful API endpoints

3. **Marketplace Web** (`pazar-web`)
   - Vue.js frontend
   - Vite build tool
   - User interface

4. **Databases**
   - PostgreSQL (H-OS)
   - MySQL (Pazar)

### Tech Stack

- **Backend:** Laravel (PHP), Node.js
- **Frontend:** Vue.js, Vite
- **Database:** PostgreSQL, MySQL
- **Infrastructure:** Docker, Docker Compose
- **CI/CD:** GitHub Actions

---

## Quick Links

### Code
- [Backend API Routes](https://github.com/bekiryara/hos-stack/blob/main/work/pazar/routes/api.php)
- [Frontend Source](https://github.com/bekiryara/hos-stack/tree/main/work/marketplace-web/src)
- [Docker Compose](https://github.com/bekiryara/hos-stack/blob/main/docker-compose.yml)

### Documentation
- [Architecture](ARCHITECTURE.html)
- [Product Roadmap](PRODUCT/PRODUCT_ROADMAP.html)
- [Runbooks](runbooks/)
- [Proofs](PROOFS/)

### Operations
- [Ops Status Runbook](runbooks/ops_status.html)
- [Security Runbook](runbooks/security.html)
- [Incident Response](runbooks/incident.html)

---

## Repository

**GitHub:** https://github.com/bekiryara/hos-stack

**GitHub Pages:** https://bekiryara.github.io/hos-stack/

---

**Last Updated:** 2026-01-20

