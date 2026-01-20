# HOS-Stack Documentation

**Repository:** [bekiryara/hos-stack](https://github.com/bekiryara/hos-stack)

## 🚀 Quick Navigation

### For Developers
- **[Quick Start](ONBOARDING.md)** - Get started in 2 commands
- **[Current State](CURRENT.md)** - Single source of truth
- **[Code Index](CODE_INDEX.md)** - Complete codebase map (for AI/ChatGPT)

### For AI/ChatGPT
- **[Code Index](CODE_INDEX.md)** - Start here! Complete system overview with all file links

### Architecture & Decisions
- **[Architecture](ARCHITECTURE.md)** - System architecture
- **[Decisions](DECISIONS.md)** - Baseline decisions and frozen items
- **[Repository Layout](REPO_LAYOUT.md)** - File structure

### Operations
- **[Daily Operations](runbooks/daily_ops.md)** - Daily snapshot guide
- **[Ops Status](runbooks/ops_status.md)** - Unified ops dashboard
- **[Public Release](runbooks/repo_public_release.md)** - Public release guide

### Product
- **[Product API Spine](PRODUCT/PRODUCT_API_SPINE.md)** - API structure
- **[MVP Scope](PRODUCT/MVP_SCOPE.md)** - MVP definition
- **[OpenAPI Spec](PRODUCT/openapi.yaml)** - API specification

### Proofs
- **[Proof Documents](PROOFS/)** - 177 proof documents

## System Overview

**H-OS + Pazar Stack** - Production-ready marketplace platform

### Services
- **H-OS API**: `http://localhost:3000` (universe governance)
- **H-OS Web**: `http://localhost:3002` (web UI)
- **Pazar App**: `http://localhost:8080` (marketplace API)

### Tech Stack
- **Backend**: Laravel (PHP), Node.js
- **Frontend**: Vue.js 3, Vite
- **Database**: PostgreSQL 16
- **Container**: Docker Compose

## Quick Links

### Code Files
- [Pazar Routes](CODE_INDEX.md#backend-routes-pazar---laravel)
- [H-OS API](CODE_INDEX.md#h-os-api-nodejs)
- [Frontend](CODE_INDEX.md#frontend-vuejs)

### Documentation
- [All Runbooks](runbooks/)
- [All Proofs](PROOFS/)
- [Architecture Docs](ARCH/)

---

**Last Updated:** 2026-01-20

