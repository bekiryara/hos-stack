# Marketplace Web

Frontend application for the Marketplace platform.

## Setup

1. Install dependencies:
```bash
npm ci
```

2. Configure environment:
   - Copy `.env.example` to `.env` (if needed)
   - Set `VITE_PAZAR_API_BASE` to your Pazar API base URL (default: `http://localhost:8080`)
   - Note: The API client will append `/api` to this base URL

3. Run development server:
```bash
npm run dev
```

4. Build for production:
```bash
npm run build
```

## Environment Variables

- `VITE_PAZAR_API_BASE`: Base URL for Pazar API (without `/api` suffix)
  - Default: `http://localhost:8080`
  - Example: `http://localhost:8080` (API client will use `http://localhost:8080/api`)

## Account Portal

The Account Portal page allows you to:
- **Store (Tenant) scope**: View listings, orders, rentals, and reservations for a tenant
- **Personal (User) scope**: View your own orders, rentals, and reservations (requires Authorization token)

### Usage

1. Select mode (Store or Personal)
2. Enter required credentials:
   - Store: Tenant ID (required), Authorization Token (optional)
   - Personal: Authorization Token (required), User ID (optional)
3. Click the appropriate button to fetch data
4. Results are displayed in JSON format with count and first item summary

### Token Security

- Tokens are masked by default (password input)
- Use "Show/Hide" button to toggle visibility
- Tokens are stored in localStorage for convenience (dev ergonomics)





