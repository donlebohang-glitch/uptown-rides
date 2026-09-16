# Uptown Rides — Phase 1

A mobile-first commuting platform built with React/Vite + Supabase.

## Included
- Authentication
- Passenger and driver registration
- Admin role
- Passenger/driver profiles
- Vehicle management data model
- Role-based dashboards
- Supabase Row Level Security
- Admin counts and management lists
- Responsive mobile-first UI

## Not included yet
Routes, pickup points, schedules, bookings, trip requests, GPS/live location, maps, traffic, pricing, shared pricing, payments, subscriptions, SOS, ratings and analytics. These are later phases.

## Setup
1. Create a Supabase project.
2. Open Supabase SQL Editor and run `supabase_schema.sql`.
3. Copy `.env.example` to `.env`.
4. Put your Supabase project URL and anon/publishable key in `.env`.
5. Install Node.js 20+.
6. Run `npm install`.
7. Run `npm run dev`.
8. Open the local URL shown by Vite.

## Create the first admin
Register normally as a passenger. In Supabase SQL Editor, replace the email and run:

```sql
update public.profiles
set role = 'ADMIN', status = 'ACTIVE'
where id = (select id from auth.users where email = 'YOUR_EMAIL@example.com');
```

Never put the Supabase service-role key in the React app. Only use the public/anon key in `.env`.

## Production
Build with `npm run build` and deploy the `dist` folder to a static host such as Vercel or Netlify. Configure the same environment variables in the host.
