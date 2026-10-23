# Yours Tutor: deployment guide (Vercel + Supabase)

Your project is a static website (no build step) with a Supabase backend.

| File | What it is |
|---|---|
| `index.html` | The public website |
| `admin.html` | The admin dashboard (opens at `/admin`) |
| `config.js` | Your Supabase URL + anon key (the only file you edit) |
| `supabase.sql` | Creates all database tables, security rules, functions and the screenshot storage bucket |
| `vercel.json` | Vercel settings (clean URLs, security headers, hides /admin from search engines) |
| `supabase/functions/telegram-notify/` | OPTIONAL: Telegram posting from the admin |

## Part 1: Supabase (database + login)
1. Go to https://supabase.com, sign in, click **New project**. Choose a name, a strong database password (save it) and the region closest to your students. Wait about 2 minutes.
2. Left menu **SQL Editor** > **New query**. Open `supabase.sql`, copy ALL of it, paste, click **Run**. It must say "Success". (Run it only once.)
3. Left menu **Authentication** > **Users** > **Add user** > **Create new user**. Enter your admin email and a strong password, tick **Auto Confirm User**, create. These are your admin login details.
4. **Authentication** > **Sign In / Providers**: turn OFF **Allow new users to sign up**, then Save. (Important: otherwise anyone could create an account and enter the admin.)
5. **Project Settings** > **API** (may be called "API Keys"). Copy the **Project URL** and the **anon public** key. Never use the `service_role` key.

## Part 2: Add your keys
Open `config.js` and replace the two placeholders:
```js
window.SUPABASE_URL = 'https://abcdxyz.supabase.co';
window.SUPABASE_ANON_KEY = 'eyJhbGciOi...your anon key...';
```
The anon key is designed to be public. The database rules in `supabase.sql` are what protect your data.

## Part 3: Put the code on GitHub
1. Create a free account at https://github.com, then **New repository** (name `yours-tutor`, Private is fine), **Create repository**.
2. Click **uploading an existing file**, drag in ALL files and folders from this project (including `supabase/`, `vercel.json`, `config.js`), then **Commit changes**.

## Part 4: Deploy on Vercel
1. Go to https://vercel.com and **Sign Up** with GitHub.
2. **Add New...** > **Project** > find `yours-tutor` > **Import**. (First time: click "Adjust GitHub App Permissions" and allow the repo.)
3. Configure the project:
   - **Framework Preset:** `Other`
   - **Root Directory:** `./`
   - **Build Command:** leave empty
   - **Output Directory:** leave empty
   - Do not add environment variables (not needed).
4. Click **Deploy**. After about 30 seconds you get a link like `https://yours-tutor.vercel.app`.
5. Your admin is at `https://yours-tutor.vercel.app/admin`.

### Alternative: deploy from your computer (Vercel CLI)
```bash
npm i -g vercel
cd yours-tutor
vercel          # first deploy (answer the questions, framework: Other)
vercel --prod   # publish to production
```

## Part 5: Test everything (5 minutes)
1. Open the site. Tap **Register Now** and register a test student with a screenshot.
2. Open `/admin`, sign in. The student appears under **Payments**. Tap **Verify**.
3. On the site, use "Check status" with the student ID. It should show Verified.
4. Post an announcement in the admin. The site notification bell should show a dot.
5. Try the **Ask AI** chat and reply from admin > **Live chat**.
6. Delete the test student in Supabase: **Table Editor** > `students`.

## Part 6: Custom domain (optional)
Vercel project > **Settings** > **Domains** > add your domain, then create the DNS records Vercel shows at your domain registrar. HTTPS is automatic.

## Updating the site later
Edit a file on GitHub (pencil icon) > **Commit**. Vercel redeploys automatically in about 30 seconds.

## Optional: Telegram posting
1. In Telegram, talk to @BotFather, create a bot, copy the token. Add the bot as admin of your channel.
2. Install the Supabase CLI, then in this folder run:
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set TELEGRAM_BOT_TOKEN=123:abc TELEGRAM_CHAT_ID=@your_channel
supabase functions deploy telegram-notify
```
Until you do this, the "Post via bot" button shows a friendly error. Everything else works.

## Troubleshooting
| Problem | Fix |
|---|---|
| "Add your Supabase keys in config.js first" | `config.js` still has the placeholders, or you did not commit the change. Edit it on GitHub and redeploy. |
| Admin login says "Invalid login credentials" | Create the user in Supabase > Authentication > Users and tick Auto Confirm. |
| Registration fails with an upload error | Re-run the storage part at the bottom of `supabase.sql`, check the bucket `payment-proofs` exists. |
| "This transaction reference was already used" | Working as intended: each payment reference can be used once. |
| Course views / charts are empty | Charts fill as students open courses and register. Charts need internet access to load Chart.js. |
| /admin shows 404 | Make sure `admin.html` is in the repo root (same folder as `index.html`). |

## Good to know
- Revenue in Finance is calculated as verified students x the price in admin > **Settings**, by registration date.
- Course Views counts how many times a course is opened on the website (anonymous).
- The demo-only features (fake live feed, automations) are not included in this production version.
