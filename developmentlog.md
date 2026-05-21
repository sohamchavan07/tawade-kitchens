# Development Log

## Fixing Render Asset Stripping Issue for Vite Assets (React + Rails)

**Date:** 2026-05-22

**Issue:** 
The application worked perfectly locally, but deploying to Render resulted in `404 ActionController::RoutingError` for static assets corresponding to the React frontend (specifically inside `/vite-assets/*`).

**Investigation:**
1. Checked `render.yaml` and `bin/render-build.sh` — The build script perfectly ran `npm run build` and outputted the assets in `public/vite-assets`. This was verified by running `bin/render-build.sh` locally.
2. Checked Rails production configuration (`config/environments/production.rb`) — `config.public_file_server.enabled` was set to `true`, and testing middleware locally confirmed that Rails/Puma natively serves files from the `public` directory just fine.
3. Discovered that although the files built correctly, they were stripped continuously by Render at the final deploy step.

**Root Cause:** 
Render automatically strips build artifacts that match `.gitignore` when copying the built application files over to the final runtime container image. Because `/public/vite-assets` was previously ignored in your `.gitignore`, Render deleted the entire built folder right before starting up Puma.

**Solution (The Fix):**
- Removed `/public/vite-assets` from `.gitignore`. 
- By allowing `public/vite-assets` to be untracked (or tracked), Render no longer strips out the folder, allowing `ActionDispatch::Static` to correctly serve the Vite compiled JavaScript/CSS in production.
