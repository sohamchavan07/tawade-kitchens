# Tawade Kitchen (तावाडे किचन) — Pickup-Only Food Ordering Platform

Tawade Kitchen is a pickup-only food ordering web application for authentic Kolhapuri homemade snacks and sweets (लाडू, चकली, फराळ).

## 📸 Screenshots

<div align="center">
  <img src="frontend/src/assets/hero-banner.jpg" alt="Tawade Kitchen landing page" width="1000" />
</div>

<div align="center">
  <img src="frontend/src/assets/ladoo.jpg" alt="Besan Ladoo product" width="320" />
  <img src="frontend/src/assets/rava-ladoo.jpg" alt="Rava Ladoo product" width="320" />
  <img src="frontend/src/assets/chakli.jpg" alt="Chakli product" width="320" />
</div>

---

## 🏗️ Architecture & Technology Stack

```
                                  ┌──────────────────────────────┐
                                  │   React + TypeScript SPA     │
                                  │ (Vite, Tailwind, Zustand UI) │
                                  └──────────────┬───────────────┘
                                                 │ REST API (JSON)
                                                 ▼
┌──────────────────────────────┐  ActiveAdmin    ┌──────────────────────────────┐
│ Admin Dashboard (/admin)     │ ──────────────> │ Ruby on Rails 8.0.5 API      │
│ (Devise Admin Authentication)│                 │ (OrderCreator Engine)        │
└──────────────────────────────┘                 └──────────────┬───────────────┘
                                                                │
                                                                ▼
                                                 ┌──────────────────────────────┐
                                                 │ PostgreSQL 16+ Database      │
                                                 │ (Unique TK-YYYYMMDD-XXXX)    │
                                                 └──────────────────────────────┘
```

- **Frontend**: React 18, TypeScript, Vite, Tailwind CSS, Zustand (Persistent Cart), Radix UI / Shadcn primitives, Lucide Icons.
- **Backend**: Ruby on Rails 8.0.5 (API mode + ActiveAdmin), Devise, Propshaft Asset Pipeline.
- **Database**: PostgreSQL 16+ with unique indexes, check constraints, and foreign key validations.
- **Timezone**: `Asia/Kolkata` (IST).
- **Currency**: Indian Rupee (`INR` / `₹`).

---

## 📋 System Requirements

- **Ruby**: `3.4.7`
- **Rails**: `8.0.5`
- **Node.js**: `20+` (Node `22.x` recommended)
- **Yarn / npm**: Yarn `1.22+` or npm `10+`
- **PostgreSQL**: `15+` (PostgreSQL `16+` recommended)

---

## 🚀 Quickstart & Local Setup

### 1. Backend Setup (Ruby on Rails)

```bash
# 1. Install Ruby dependencies
bundle install

# 2. Configure environment variables
cp .env.example .env

# 3. Create and migrate database
bin/rails db:create
bin/rails db:migrate

# 4. Seed database with authentic Tawade Kitchen menu and default admin
bin/rails db:seed

# 5. Run the Rails server
bin/rails server -p 3000
```

> **Default Admin Account** (seeded in development):
> - **URL**: `http://localhost:3000/admin`
> - **Email**: `admin@tawadekitchen.com`
> - **Password**: `password` *(Change immediately in production)*

---

### 2. Frontend Setup (React + Vite)

```bash
# 1. Navigate to frontend directory
cd frontend

# 2. Install dependencies
npm install

# 3. Configure frontend environment variables
cp .env.example .env

# 4. Start the frontend development server
npm run dev
```

Frontend will run at `http://localhost:8080` (or `http://localhost:5173`).

---

## ⚙️ Configuration & Business Settings

### Centralized Business Schedule (`config/initializers/pickup_schedule.rb` & `frontend/src/config/pickupConfig.ts`)

| Setting | Value | Description |
| :--- | :--- | :--- |
| **Business Name** | `Tawade Kitchen` | Name displayed across receipt, banner, and WhatsApp |
| **Pickup Address** | `Plot no 7, Mukt Sainik Vasahat, Opp Mukt Sainik Udyan, PO: Gur Market Yard, Kolhapur, Maharashtra 416005` | Confirmed pickup location |
| **Google Maps Link** | `https://maps.app.goo.gl/fE2oV7vcLptDP2hr6` | Verified store location link |
| **WhatsApp Support** | `9860002903` (+919860002903) | Pre-filled customer receipt messaging destination |
| **Operating Hours** | `09:00` to `20:00` (9:00 AM – 8:00 PM IST) | Configurable pickup slot range (30-min intervals) |
| **Timezone** | `Asia/Kolkata` | Standardized across model dates and frontend validators |

> ⚠️ **CRITICAL SECURITY NOTE FOR FRONTEND ENV VARIABLES**:
> All variables in `frontend/.env` prefixed with `VITE_` (such as `VITE_API_URL`, `VITE_UPI_ID`, `VITE_WHATSAPP_NUMBER`) are compiled into public JavaScript client bundles. **NEVER** put private API keys, database passwords, or secret credentials in frontend environment files.

---

## 🛡️ Core Business Rules & Security

### 1. Strict Pickup-Only Policy
- **No Delivery**: Tawade Kitchen does not offer home delivery. No delivery addresses, delivery charges, driver assignments, GPS tracking, or "out for delivery" statuses exist in the system.

### 2. Server-Side Price Recalculation Engine (`OrderCreator`)
- **Zero Client Trust**: Client-submitted unit prices, item names, subtotals, and total amounts are strictly ignored.
- **Database Price Lookup**: Every product is looked up in the database inside an `ActiveRecord::Base.transaction`.
- **Exact Money Calculations**: All calculations use `BigDecimal` arithmetic.
- **Rollback Safety**: If any item ID is missing, out of stock (`is_available: false`), has invalid quantity, or pickup time is outside operating hours, the entire order rolls back atomically.

### 3. Concurrency-Safe Order Numbering
- **Format**: `TK-YYYYMMDD-XXXX` (e.g. `TK-20260825-7K9P`).
- Avoids `count + 1` concurrency race conditions by generating timestamped cryptographic alphanumeric suffixes with database-level unique index enforcement (`index_orders_on_order_number`).

### 4. Manual UPI Verification Workflow
- `pay_at_pickup` $\rightarrow$ `payment_status: "pending"`.
- `upi` with customer UTR $\rightarrow$ `payment_status: "submitted"`.
- **Never Auto-Verified**: Entering a UTR/Transaction Reference never marks an order as paid.
- **Admin Verification**: Authenticated staff verify receipt in bank/UPI account and manually trigger **Verify Payment** (`verified`) or **Mark Failed** (`failed`) in ActiveAdmin.
- **No Sensitive Credential Requests**: The system never asks for or stores UPI PINs, OTPs, CVVs, card numbers, or passwords.

### 5. Order Fulfillment State Machine
```
[ pending ] ──► [ confirmed ] ──► [ preparing ] ──► [ ready_for_pickup ] ──► [ collected ]
     │                │                 │                   │
     ▼                ▼                 ▼                   ▼
[ cancelled ]   [ cancelled ]     [ cancelled ]       [ cancelled ]
```

### 6. Decoupled WhatsApp Integration
- Order creation is 100% independent of WhatsApp.
- After receiving HTTP 201 Created from the backend, the customer is shown an optional "WhatsApp वर ऑर्डर तपशील पाठवा (Send details to WhatsApp)" button that pre-fills order details using server-verified attributes.

---

## 🔌 API Reference

### 1. Public Menu Endpoints

#### `GET /api/v1/products`
Returns available menu items (`is_available == true`). Supports optional `?category=Sweets` filter.
```json
[
  {
    "id": 1,
    "name": "Besan Ladoo",
    "description": "Homemade besan ladoo with pure ghee and dry fruits.",
    "price": 580.0,
    "category": "Sweets",
    "is_available": true,
    "preparation_time": 15,
    "vegetarian": true
  }
]
```

#### `GET /api/v1/products/:id`
Returns single product details.

---

### 2. Pickup Order Endpoints

#### `POST /api/v1/orders`
Creates a pickup order.

**Request Body**:
```json
{
  "order": {
    "customer_name": "Ramesh Patil",
    "customer_phone": "+91 98600 02903",
    "pickup_date": "2026-08-25",
    "pickup_time": "11:30 AM",
    "payment_method": "upi",
    "payment_reference": "UTR492817294829",
    "notes": "Pack in separate boxes",
    "items": [
      { "product_id": 1, "quantity": 2 },
      { "product_id": 4, "quantity": 1 }
    ]
  }
}
```

**Response (HTTP 201 Created)**:
```json
{
  "order_number": "TK-20260825-7K9P",
  "status": "pending",
  "payment_method": "upi",
  "payment_status": "submitted",
  "pickup_date": "2026-08-25",
  "pickup_time": "11:30 AM",
  "customer_name": "Ramesh Patil",
  "total_amount": 1560.0,
  "notes": "Pack in separate boxes",
  "pickup_address": "Plot no 7, Mukt Sainik Vasahat, Opp Mukt Sainik Udyan, PO: Gur Market Yard, Kolhapur, Maharashtra 416005",
  "operating_hours": "9:00 AM - 8:00 PM IST",
  "items": [
    { "id": 1, "product_id": 1, "name": "Besan Ladoo", "unit_price": 580.0, "quantity": 2, "subtotal": 1160.0 },
    { "id": 2, "product_id": 4, "name": "Chakli", "unit_price": 400.0, "quantity": 1, "subtotal": 400.0 }
  ],
  "created_at": "2026-08-25T07:54:00.000Z"
}
```

#### `GET /api/v1/orders/:order_number`
Public lookup of customer order status.
- Omit customer phone number and administrative metadata.
- Returns `404 Not Found` if order does not exist.

---

## 🧪 Testing

### Backend Rails Tests
```bash
bin/rails test
```
*Executes all 43 unit, service, integration, and ActiveAdmin controller tests (0 failures).*

### Frontend Tests, Lint & Build
```bash
cd frontend

# Run unit tests (useCart, phone validation, WhatsApp formatter)
npm test

# Run ESLint check
npm run lint

# Run production build
npm run build
```

---

## 🚢 Production Deployment Guide

### 1. Rails API Deployment
- Set `RAILS_ENV=production`.
- Set `SECRET_KEY_BASE` (generate using `bin/rails secret`).
- Set `DATABASE_URL=postgresql://user:password@host:5432/dbname`.
- Set `ALLOWED_ORIGINS=https://tawadekitchen.com,https://www.tawadekitchen.com`.
- Run migrations: `bin/rails db:migrate`.
- Compile assets for ActiveAdmin: `bin/rails assets:precompile`.

### 2. Frontend React Deployment (Vercel / Netlify / Cloudflare)
- Build command: `npm run build`
- Output directory: `dist`
- Environment Variables:
  - `VITE_API_URL=https://api.tawadekitchen.com`
  - `VITE_WHATSAPP_NUMBER=9860002903`
  - `VITE_UPI_ID=tawadekitchen@upi`
  - `VITE_UPI_QR_IMAGE_URL=/assets/upi-qr.png`

### 3. Database Backup & Rollback Safety
- **Backup**:
  ```bash
  pg_dump -Fc --no-acl --no-owner -h <host> -U <user> <dbname> > backup_$(date +%Y%m%d_%H%M%S).dump
  ```
- **Restore**:
  ```bash
  pg_restore --verbose --clean --no-acl --no-owner -h <host> -U <user> -d <dbname> backup_file.dump
  ```
- **Safe Rollback**:
  ```bash
  bin/rails db:rollback STEP=1
  ```

---

## ✅ Pre-Launch Manual QA Checklist

1. [ ] **Homepage & Menu**: Verify all menu items load with authentic local photos, prices in INR, veg badges, and prep times.
2. [ ] **Availability Toggling**: Mark an item Out of Stock in ActiveAdmin; confirm it displays as unavailable and cannot be added to cart.
3. [ ] **Persistent Cart**: Add items, adjust quantities, refresh the page, and confirm cart items and subtotals persist in `localStorage`.
4. [ ] **Validation Guardrails**:
   - Try entering invalid phone numbers (e.g. 5 digits or letters) $\rightarrow$ rejected.
   - Try selecting past pickup date $\rightarrow$ rejected.
   - Try submitting UPI order without UTR $\rightarrow$ rejected.
5. [ ] **Order Placement (Pay at Pickup)**:
   - Submit order $\rightarrow$ verify HTTP 201 Created and redirection to `/order-confirmation/:orderNumber`.
   - Confirm cart is automatically cleared.
   - Confirm order appears in ActiveAdmin under *Pending* with `payment_status: "pending"`.
6. [ ] **Order Placement (UPI)**:
   - Submit order with 12-digit UTR $\rightarrow$ verify order created with `payment_status: "submitted"`.
   - Confirm confirmation page shows *"Awaiting manual verification (पडताळणी बाकी)"*.
   - In ActiveAdmin, click **Verify Payment** $\rightarrow$ refresh confirmation page $\rightarrow$ status updates to *"Payment verified (पेमेंट पडताळणी झाली)"*.
7. [ ] **Fulfillment Flow**: Transition order in ActiveAdmin: `Pending` $\rightarrow$ `Confirmed` $\rightarrow$ `Preparing` $\rightarrow$ `Ready for Pickup` $\rightarrow$ `Collected`.
8. [ ] **Optional WhatsApp Receipt**: Click *"WhatsApp उघडा"* on confirmation page $\rightarrow$ verify pre-filled message has exact order number, items, and total amount.
9. [ ] **Privacy**: Confirm customer phone number is visible only inside ActiveAdmin and never on the public confirmation page.

---

## 🔒 Security & Compliance Summary

- **Authentication**: ActiveAdmin protected by Devise database authentication.
- **Authorization**: Public endpoints expose only safe attributes; admin management endpoints require an active `AdminUser` session.
- **Input Sanitization**: Strong Parameters enforce allowed fields on all controller actions.
- **CORS Protection**: Origin-restricted through `Rack::Cors`.
- **Zero Financial Secrets**: No banking passwords, CVVs, card details, or UPI PINs are ever collected or processed.
