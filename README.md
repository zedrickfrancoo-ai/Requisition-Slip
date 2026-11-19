# Stores Requisition (GitHub Pages + Supabase)

## 1. Database (5 min)
1. Create a free project at supabase.com.
2. SQL Editor > paste all of `schema.sql` > Run (creates tables, security rules, release function and your cost center / GL codes).
3. Authentication > Providers > Email: on. (Optional: turn off "Confirm email" for easier testing.)
4. Settings > API: copy **Project URL** and **anon public key**. Paste them at the top of `index.html` (SB_URL, SB_KEY). The anon key is safe to publish; the security rules protect the data.

## 2. First admin
Open the site, create your account, then in Supabase SQL Editor run:

    update profiles set role='admin', active=true where email='you@example.com';

Other people request accounts; you approve them and set roles under **Users**.

## 3. Stock
Sign in as admin > Stock > upload `items.csv` (3,772 items from the old system).

## 4. Publish
Upload every file here to a GitHub repo > Settings > Pages > deploy from `main`. Open the site on a phone and choose "Add to Home Screen" to install it as an app.

Never upload `requisition.db` or `secret.key` to GitHub.
