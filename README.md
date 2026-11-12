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

Open `http://localhost:3000` in the same browser profile you use for email. From the sign-in dialog, choose **Forgot password?** to request a recovery email. Open the link in that same browser profile; PKCE stores a one-time verifier there. The app exchanges the callback code before showing the new-password form. Recovery links previously sent while the app had no recovery page may be expired; request a fresh one after configuring the redirect.

## Google sign-in setup

Google sign-in is available in the web, Android, and iOS builds. The Google provider client secret belongs only in Supabase's provider settings; do not add it to Flutter config or source control.

1. In Google Cloud, create an OAuth client ID for a **Web application**. Add `http://localhost:3000` as an authorized JavaScript origin. Add the Supabase callback URL shown in **Supabase > Authentication > Sign In / Providers > Google** as an authorized redirect URI.
2. In Supabase, open **Authentication > Sign In / Providers > Google**, enable Google, and enter the OAuth client ID and secret from Google Cloud.
3. In **Authentication > URL Configuration > Redirect URLs**, allow `http://localhost:3000`, `http://localhost:3000/?auth_flow=recovery`, `io.supabase.fluttershop://login-callback`, and `io.supabase.fluttershop://login-callback?auth_flow=recovery`.
4. Run the web app with `flutter run -d web-server --web-port 3000`, open `http://localhost:3000`, then use **Sign in > Continue with Google**. For Android/iOS, use the corresponding Flutter device; those builds include the `io.supabase.fluttershop` callback scheme.

Google accounts can sign in as customers. Product creation, editing, and deletion remain restricted by the admin role and Supabase RLS policies.

The local `supabase_config.json` file provides the project URL and publishable key. The publishable key is for client use; never put a secret or service-role key in the app.

## Supabase setup

- `supabase/seed.sql` creates the public-read `products` table and adds sample catalog items.
- `supabase/admin_crud.sql` adds admin-only product create, edit, and delete policies.

Running `seed.sql` again re-adds any deleted sample products (and updates existing sample rows), so only rerun it when you intend to restore the sample catalog.

To enable catalog management, run `admin_crud.sql` in the Supabase SQL Editor, create an Auth user in **Authentication > Users**, then edit the commented SQL block in that file with that user's email and run it. Sign out and back in through the app so the refreshed session receives the admin role. Only that admin role can write products; store visitors retain read-only access.
