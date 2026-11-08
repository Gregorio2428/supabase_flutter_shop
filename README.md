# E-commerce

A Flutter storefront backed by Supabase. The catalog supports Supabase-side price filtering, name search, and six-item pagination. Product details open when a card is tapped.

## Run the app

From this folder, run:

```powershell
flutter pub get
flutter run
```

## Password recovery on the local web app

Recovery emails need a page that can receive Supabase's redirect. In the Supabase Dashboard, open **Authentication > URL Configuration** and add `http://localhost:3000` to **Redirect URLs**. Set the **Site URL** to `http://localhost:3000` while developing locally if the invitation/recovery email falls back to the Site URL.

Start the Flutter web app before opening a newly requested recovery link:

```powershell
flutter run -d web-server --web-port 3000
```

Open `http://localhost:3000` in the same browser profile you use for email. From the admin sign-in dialog, choose **Forgot password?** to request a recovery email. Open the link in that same browser profile; PKCE stores a one-time verifier there. The app exchanges the callback code before showing the new-password form. Recovery links previously sent while the app had no recovery page may be expired; request a fresh one after configuring the redirect.

The local `supabase_config.json` file provides the project URL and publishable key. The publishable key is for client use; never put a secret or service-role key in the app.

## Supabase setup

- `supabase/seed.sql` creates the public-read `products` table and adds sample catalog items.
- `supabase/admin_crud.sql` adds admin-only product create, edit, and delete policies.

Running `seed.sql` again re-adds any deleted sample products (and updates existing sample rows), so only rerun it when you intend to restore the sample catalog.

To enable catalog management, run `admin_crud.sql` in the Supabase SQL Editor, create an Auth user in **Authentication > Users**, then edit the commented SQL block in that file with that user's email and run it. Sign out and back in through the app so the refreshed session receives the admin role. Only that admin role can write products; store visitors retain read-only access.
