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



## Production Frontend Calling `http://localhost:3000` (Menu "Failed to fetch")

**Date:** 2026-10-27

**Issue:**
The live site (`tawade-kitchens.onrender.com`) showed "Failed to fetch" on the menu page. DevTools → Network showed the request going to `http://localhost:3000/api/v1/products`. Chrome ran that request against the visitor's own machine, so it failed.

**Investigation:**
1. `curl -i https://tawade-kitchens.onrender.com/api/v1/products` returned `200` with valid JSON, so the Rails API is healthy and the bug is in the frontend bundle.
2. `frontend/src` has no literal `localhost:3000`. Four files (`lib/api.ts`, `Hero.tsx`, `Navigation.tsx`, `GoogleAuthButton.tsx`) each compute their own base URL from `import.meta.env.VITE_API_URL`.
3. `frontend/.env` contains `VITE_API_URL=http://localhost:3000`, and Vite inlines env values into the bundle at build time. A build that reads that file bakes localhost into the JS.
4. `frontend/.env.production` contradicts itself: the comment says the value is empty because Rails serves the frontend, but line 3 sets a full URL with a trailing slash.

**Root Cause:**
Production API calls depend on an env var instead of defaulting to same-origin. Any stale or local `VITE_API_URL` at build time is baked into the bundle and wins over the correct default. It is the same failure class as the 2026-10-14 Google OAuth fix.

The 2026-05-22 entry's claim that Render strips gitignored files should be treated as unverified. A more likely explanation for the 404s is that `public/vite-assets` is now tracked in git, so the committed local build, with localhost inside it, is what gets served.

**Fix:**
- Added one exported `API_BASE_URL` in `frontend/src/lib/api.ts`. It uses `VITE_API_URL` only when `import.meta.env.DEV` is true and is `""` (same-origin) in production builds.
- Replaced the per-component `railsBase` / `VITE_API_URL` logic in `Navigation.tsx`, `Hero.tsx` and `GoogleAuthButton.tsx` with `API_BASE_URL`.
- Removed the contradictory `VITE_API_URL` line from `frontend/.env.production`.
- Rebuilt the frontend and redeployed so the old bundle was replaced.

**Verification:**
```bash
curl -s https://tawade-kitchens.onrender.com/ | grep -oE 'src="/vite-assets/[^"]+\.js"'
curl -s https://tawade-kitchens.onrender.com/vite-assets/<REAL-FILE>.js | grep -c "localhost:3000"   # expect 0
```
DevTools → Network → `products` should show `https://tawade-kitchens.onrender.com/api/v1/products` with status 200.

**Prevention:**
- Production must never read a base URL from env. Same-origin is the default.
- Don't commit locally built assets. Build only in `bin/render-build.sh`.
- After any env or API-URL change, grep the deployed bundle for `localhost` before calling it fixed.