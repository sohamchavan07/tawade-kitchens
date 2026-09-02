# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tawade Kitchen is a pickup-only food ordering web application for authentic Kolhapuri homemade snacks and sweets. It's a dual-stack application:

- **Backend**: Ruby on Rails 8.0.5 API mode with ActiveAdmin, Devise authentication, PostgreSQL database
- **Frontend**: React 18 + TypeScript with Vite, Tailwind CSS, Zustand (persistent cart), Radix UI/Shadcn, Lucide Icons
- **Architecture**: ActiveAdmin for admin dashboard + React SPA with API proxy

## High-Level Architecture

The application follows a strict server-side price recalculation pattern:

```
[React Frontend] ←→ [Rails API v1] ←→ [PostgreSQL]
     (Vite, 8080)      (Rails, 3000)      (16+)

Key Business Rules:
- Zero client trust: Frontend prices are display-only snapshots
- OrderCreator service: Validates and rebuilds order with database price lookup
- Concurrency-safe order numbers: TK-YYYYMMDD-XXXX format
- Manual UPI verification (never auto-verified)
- Pickup-only policy (no delivery functionality)
- Order state machine: pending → confirmed → preparing → ready_for_pickup → collected
```

## Core Components

### Backend Services

**OrderCreator** (app/services/order_creator.rb)
- Validates all order inputs (customer, pickup schedule, payment, items)
- Fetches current product prices from database (ignoring client-submitted prices)
- Performs atomic transaction with stock deduction and order creation
- Enforces limits: MAX_QUANTITY_PER_ITEM (50), MAX_TOTAL_ITEMS (100), MAX_TOTAL_AMOUNT (₹100000)

**Rails Models**
- `Order`: State machine, payment workflow, order number generation
- `Product`: Menu items with availability, stock tracking

**API Controllers**
- `api/v1/products`: Public menu endpoints
- `api/v1/orders`: Order creation and customer lookup

### Frontend Services

**useCart** (frontend/src/hooks/useCart.ts)
- Persistent cart using Zustand middleware
- Display-only price calculations (backend recalculates)

**Validation** (frontend/src/hooks/validation.ts)
- Indian phone number validation and normalization
- Pickup date/time validation against operating hours
- Checkout form validation (name, phone, date, time, UPI UTR when applicable)

**WhatsApp Utilities** (frontend/src/lib/whatsapp.ts)
- Builds pre-filled WhatsApp messages with order details
- Formats bilingual status messages (English/Marathi)

## Development Commands

### Backend (Rails)

```bash
# Install dependencies
bundle install

# Configure environment
cp .env.example .env

# Database setup
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed  # Seeds authentic menu and default admin

# Run Rails server
bin/rails server -p 3000

# Tests
bin/rails test                    # All 43 tests (unit, service, integration, ActiveAdmin)
```

### Frontend (React)

```bash
# Navigate to frontend
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev                    # Runs on http://localhost:8080

# Run tests
npm test                      # Tests: useCart, phone validation, WhatsApp formatter

# ESLint check
npm run lint

# Production build
npm run build                 # Outputs to ../public (Vite)
```

### Configuration

```bash
# Business schedule config
# Config source: config/initializers/pickup_schedule.rb
# Frontend source: frontend/src/config/pickupConfig.ts

# Frontend environment variables (VITE_ prefix - compiled into JS)
VITE_API_URL=https://api.tawadekitchen.com
VITE_WHATSAPP_NUMBER=9860002903
VITE_UPI_ID=tawadekitchen@upi
VITE_UPI_QR_IMAGE_URL=/assets/upi-qr.png
```

## Key Files and Patterns

### Backend Routes (config/routes.rb)
- Devise for admin_users (ActiveAdmin) and regular users (SPA handles auth pages)
- API namespace: `/api/v1/products` and `/api/v1/orders`
- Fallback route for React Router: `get "*path" -> "application#fallback_index_html"`

### Order Creation Flow
1. Frontend validates inputs and displays errors
2. Frontend POSTs to `/api/v1/orders` with items (prices ignored)
3. OrderCreator service validates, fetches database prices, creates order atomically
4. Returns order summary with recalculated prices and order number
5. Customer gets confirmation page with optional WhatsApp sharing

### Frontend Configuration
- `pickupConfig.ts`: Centralized business configuration
- `getPickupTimeSlots()`: Generates 30-minute interval slots within operating hours (09:00-20:00 IST)

## Testing Approach

### Backend Tests
- **Unit tests**: Individual model and service methods
- **Service tests**: OrderCreator validation and error scenarios
- **Integration tests**: Full order creation flow
- **ActiveAdmin tests**: Admin dashboard functionality

### Frontend Tests
- **useCart**: Persistent cart operations, add/remove/update quantities
- **Validation**: Phone normalization, date validation, checkout form validation
- **WhatsApp**: Message building, URL encoding, status formatting

## Deployment Configuration

### Rails Production
```bash
RAILS_ENV=production
SECRET_KEY_BASE=$(rails secret)
DATABASE_URL=postgresql://user:password@host:5432/dbname
ALLOWED_ORIGINS=https://tawadekitchen.com,https://www.tawadekitchen.com
bin/rails db:migrate
bin/rails assets:precompile
```

### Frontend Production
```bash
# Vercel / Netlify / Cloudflare
Build command: npm run build
Output directory: dist
```

### Database Backup/Restore
```bash
# Backup
pg_dump -Fc --no-acl --no-owner -h <host> -U <user> <dbname> > backup_$(date +%Y%m%d_%H%M%S).dump

# Restore
pg_restore --verbose --clean --no-acl --no-owner -h <host> -U <user> -d <dbname> backup_file.dump

# Safe rollback
bin/rails db:rollback STEP=1
```

## Common Development Tasks

1. **Add new menu item**: Update seeds.rb, verify Product model validations
2. **Modify pickup schedule**: Update pickup_schedule.rb and pickupConfig.ts
3. **Add new payment method**: Update Order::PAYMENT_METHODS, OrderCreator validation
4. **Extend order status workflow**: Update ALLOWED_STATUS_TRANSITIONS in Order model
5. **Fix business rule**: Modify OrderCreator service validation logic
6. **Update admin functionality**: ActiveAdmin will auto-generate based on models

## Important Conventions

- **Price handling**: All prices use `BigDecimal` for exact monetary calculations
- **Order numbers**: Generated with `TK-YYYYMMDD-randomSuffix`, database unique constraint
- **Time handling**: All times in `Asia/Kolkata` timezone
- **Validation**: Server-side validation only - frontend shows errors, backend enforces rules
- **Phone format**: Stored normalized (10-digit Indian mobile), displayed with +91 prefix when needed
- **UPI payments**: Never auto-verified - admin must manually verify payment status
- **Cart persistence**: Uses `localStorage` with key "tawade-cart-storage"