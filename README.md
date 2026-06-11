# Mivtzah-For-YKP

# Mivtzah Sventzich — Setup Guide

## Files
| File | Purpose |
|------|---------|
| `index.html` | The entire app (single file) |
| `manifest.json` | PWA install metadata |
| `sw.js` | Service worker (offline cache) |
| `supabase_setup.sql` | One-time DB setup for Supabase |

---

## Step 1 — Create a Supabase project
1. Go to [supabase.com](https://supabase.com) and sign in (free tier is fine)
2. Click **New Project**, give it a name, set a DB password, pick a region
3. Wait ~2 minutes for it to spin up

## Step 2 — Run the SQL schema
1. In your Supabase dashboard → **SQL Editor**
2. Paste the contents of `supabase_setup.sql` and click **Run**
3. This creates all tables, default questions, and default admin password (`YKP2024`)

## Step 3 — Get your API keys
In your Supabase dashboard → **Settings → API**:
- Copy **Project URL** (looks like `https://abcxyz.supabase.co`)
- Copy **anon / public** key (long JWT string)

## Step 4 — Configure the app
Open `index.html` and find these lines near the top:
```js
const SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
const ADMIN_PASSWORD_FALLBACK = 'YKP2024';
```
Replace with your real values. The password fallback is only used when Supabase isn't reachable.

**Also replace the Rebbe photo URL** in the `<img id="rebbe-img">` tag.

## Step 5 — Change the admin password
Either:
- In Supabase SQL Editor: `update app_settings set value = 'YourPassword' where key = 'admin_password';`
- Or change `ADMIN_PASSWORD_FALLBACK` in `index.html`

## Step 6 — Deploy (GitHub Pages — free)
1. Create a new GitHub repo
2. Upload all 4 files (`index.html`, `manifest.json`, `sw.js`, `supabase_setup.sql` optional)
3. Go to repo **Settings → Pages → Source: main branch → / (root)**
4. Your app is live at `https://yourusername.github.io/reponame`

---

## Using the App

### Camper Login
- Campers tap their NFC card (keyboard wedge → auto-types + Enter)
- Or they type their NFC ID in the visible field and tap **Sign In**

### Admin Access
- On the login screen, tap the tiny **Admin** button (bottom right)
- Enter the admin password

### Assigning NFC Cards to Campers
1. Admin → Campers → Add Camper (enter name)
2. Click **Edit** on the camper
3. In the **NFC Card ID** field, tap the physical card (it types the ID) → Save
- Or manually type the card's ID number

### Managing Admin Password
Update directly in Supabase:
```sql
update app_settings set value = 'NewPassword' where key = 'admin_password';
```

---

## Offline Mode
When Supabase isn't configured (or unreachable), the app falls back to `localStorage`. All features work — data is stored in the browser on that device only.

To use the app offline with data shared across devices, you **must** configure Supabase.
