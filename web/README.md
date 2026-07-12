# ChengetAI web

Next.js (App Router) app with two things in it:

- **`/`** — the public marketing landing page, including a "live from the
  ChengetAI API" stats section pulled server-side from `/feed/trending`.
- **`/admin/*`** — a password-gated internal dashboard: an overview with
  KPIs and the province hotspot map, a report moderation queue, flagged-number
  review, and Sentinel job history. See `src/lib/auth.ts` and
  `docs/architecture.md` → "Admin dashboard auth" (in the repo root) for how
  the gate works and its known limitations.

Both consume the FastAPI backend in `../backend/` — see `../docs/api.md` for
the endpoints and `src/lib/api.ts` for the typed client.

## Setup

```bash
npm install
cp .env.example .env.local   # set ADMIN_PASSWORD; CHENGETAI_API_BASE_URL defaults to localhost:8000
npm run dev
```

The backend must be running for any page to show real data; every page
that fetches from it degrades to a "backend unreachable" notice instead of
crashing if it isn't (see `src/components/BackendOfflineNotice.tsx`).

## Structure

```
src/
├── app/
│   ├── page.tsx                    # landing page
│   ├── admin/
│   │   ├── login/page.tsx          # no auth gate (middleware allowlists this route)
│   │   └── (dashboard)/            # route group: everything here shares the sidebar layout
│   │       ├── layout.tsx
│   │       ├── page.tsx            # overview
│   │       ├── reports/page.tsx
│   │       ├── numbers/page.tsx
│   │       └── sentinel/page.tsx
│   └── api/admin/{login,logout}/route.ts
├── components/                     # Badge, StatCard, SiteHeader/Footer, AdminNav, BackendOfflineNotice
├── lib/
│   ├── api.ts                      # typed fetch wrapper over the FastAPI backend
│   ├── types.ts                    # mirrors backend/app/schemas/*.py
│   ├── auth.ts                     # admin session cookie derivation
│   ├── risk-colors.ts              # shared severity → Tailwind color mapping
│   └── config.ts
└── proxy.ts                        # Next.js middleware: gates /admin/* behind the session cookie
```

## Commands

```bash
npm run dev      # dev server, port 3000
npm run build    # production build
npm run lint      # eslint
```
