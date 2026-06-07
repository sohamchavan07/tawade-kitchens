# Tawade Kitchen Project Brief & Roadmap

## Project Overview
**Client/Business**: Tawade Kitchen  
**Location**: Kolhapur, Maharashtra  
**Current Site**: https://tawade-kitchen.vercel.app/ (Static Next.js)  
**Products**: Authentic homemade Indian snacks — Besan Ladoo, Rava Ladoo, Bundi Ladoo, Chakli, Shankarpali, Chivda, Anarsa, Bakarvadi, Sev, and more (expand to Puran Poli, lunch thalis, chapati bhaji, rice as mentioned).

**Goal**: Transform static brochure site into automated online ordering platform + basic CRM to enable direct customer orders, reduce manual WhatsApp handling, increase revenue, and build repeat business.

## Business Objectives
- Enable online menu browsing, cart, and checkout
- Accept payments (Razorpay/UPI)
- Automate order confirmations (WhatsApp/Email)
- Capture customer data for CRM (repeat orders, loyalty)
- Admin dashboard for order management
- Position for scaling to delivery/pickup

## Target Revenue Impact
- Goal: Move from manual orders to 20–50+ online orders/week
- Track: Orders processed, revenue added to Lambo Fund

## Tech Stack (RoR + Next.js Hybrid)
- **Frontend**: Next.js (Vercel) – Enhanced menu, cart, responsive design
- **Backend**: Ruby on Rails API (Render/Railway)
- **Database**: PostgreSQL
- **Payments**: Razorpay
- **Auth**: Devise/JWT
- **Admin**: ActiveAdmin
- **Notifications**: Sidekiq + Gupshup/Twilio for WhatsApp
- **CRM**: Simple customer/order models + export to Zoho/Google Sheets

## Features List (MVP)
1. Product Catalog (with images, prices, variants)
2. Shopping Cart & Checkout
3. Order Management (status: pending, confirmed, delivered)
4. Customer Profiles & Order History
5. Admin Dashboard
6. Basic Analytics (orders count, revenue)
7. Responsive Mobile-First Design

## Future Phases
- Delivery integration (local)
- Loyalty program
- SEO for "puran poli Kolhapur" etc.
- AI recommendations

## Timeline & Milestones
- Week 1: RoR setup + models
- Week 2: API + Next.js integration
- Week 3: Payments + Notifications
- Week 4: Testing, launch, marketing

## Portfolio Case Study Sections
- Problem (manual orders)
- Solution (automated system)
- Tech used
- Results (metrics after launch)
- Images/Screenshots

## Marketing Ideas
- LinkedIn post: Before/After ordering flow
- Social A/B tests for menu highlights

**Next Actions**:
- Set up RoR repo
- Share current Next.js code structure if needed
- Start with Product model

---
*Document for freelance portfolio & project tracking. Update with progress toward Lambo SVJ.*