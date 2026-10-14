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

## Fixing Google OAuth Redirect to localhost on Render

**Date:** 2026-10-14

**Issue:**
Users clicking "Continue with Google" on the production site were being redirected to `http://localhost:3000/users/auth/google_oauth2` instead of the Render domain.

**Root Cause:**
There were two places generating the Google auth URL:
1. The React button (`frontend/src/components/GoogleAuthButton.tsx`) had a hardcoded localhost fallback: `http://localhost:3000`.
2. The Rails Devise OmniAuth config (`config/initializers/devise.rb`) also depended on `OAUTH_BASE_URL` and could fall back to a localhost host when the env was missing or stale.

Because the frontend is built as static Vite assets, any stale build still contained the localhost string even after env vars were updated.

**Fix applied:**
- Removed the hardcoded localhost fallback from the frontend Google auth button.
- Updated the frontend logic to prefer:
  - `VITE_API_URL`
  - `VITE_RAILS_BASE_URL`
  - `window.location.origin`
- Updated Rails OmniAuth config to build the callback URL from:
  - `ENV["OAUTH_BASE_URL"]` if present
  - otherwise `https://#{ENV.fetch("RAILS_HOST", "localhost")}`
- Ensured production env vars were set for Render:
  - `OAUTH_BASE_URL=https://tawade-kitchens.onrender.com`
  - `VITE_API_URL=https://tawade-kitchens.onrender.com`
  - `RAILS_HOST=tawade-kitchens.onrender.com`
  - `RAILS_PROTOCOL=https`

**Important:**
After changing env vars, the app needs a fresh deploy/rebuild so the old built frontend bundle is replaced. Without rebuilding, the old localhost string remains in the served JS and the redirect keeps happening.
