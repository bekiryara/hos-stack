# Frontend Refresh Discipline

## Overview

This document describes when to use hard refresh vs container rebuild for frontend changes.

## When to Use Hard Refresh (Ctrl+F5 / Cmd+Shift+R)

**Use hard refresh when:**
- Only UI text/layout changes were made
- Frontend dev server is running (`npm run dev`)
- Changes are in Vue/React components (not build config)
- You see changes in browser dev tools but not in rendered page

**Steps:**
1. Ensure dev server is running
2. Open browser
3. Press `Ctrl+Shift+R` (Windows/Linux) or `Cmd+Shift+R` (Mac)
4. Changes should appear immediately

## When to Rebuild Container

**Use container rebuild when:**
- Docker-served built assets are used (production build)
- Changes were made to build configuration (vite.config, webpack.config, etc.)
- New dependencies were added (package.json changes)
- Environment variables changed
- Changes don't appear after hard refresh

**Steps:**
1. Run: `.\ops\frontend_refresh.ps1 -Build`
2. Wait for build to complete
3. Open browser and hard refresh (Ctrl+Shift+R)

## When to Restart Container (No Rebuild)

**Use container restart when:**
- Only restarting services (no code changes)
- Troubleshooting service issues
- Applying environment variable changes (no rebuild needed)

**Steps:**
1. Run: `.\ops\frontend_refresh.ps1` (default: restart only)
2. Open browser and hard refresh

## When to Restart Core Services

**Use service restart when:**
- API contracts changed (backend routes, endpoints)
- Database migrations were run
- Core service configuration changed

**Steps:**
1. Restart affected services: `docker compose restart <service>`
2. Or restart all: `docker compose restart`

## Quick Reference

| Change Type | Action | Command |
|------------|--------|---------|
| UI text/layout (dev server) | Hard refresh | `Ctrl+Shift+R` in browser |
| UI text/layout (Docker) | Restart container | `.\ops\frontend_refresh.ps1` |
| Build config / dependencies | Rebuild container | `.\ops\frontend_refresh.ps1 -Build` |
| API contracts | Restart services | `docker compose restart <service>` |

## Troubleshooting

**Changes not appearing after hard refresh:**
1. Check browser console for errors
2. Clear browser cache completely
3. Try incognito/private mode
4. Rebuild container: `.\ops\frontend_refresh.ps1 -Build`

**Container rebuild fails:**
1. Check Docker logs: `docker compose logs <service>`
2. Verify Dockerfile syntax
3. Check disk space
4. Try: `docker compose build --no-cache <service>`

## Notes

- This script does NOT modify git state
- Always hard refresh browser after container operations
- For production deployments, use full rebuild process

