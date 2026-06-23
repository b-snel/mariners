# Deploying mariners.bsnel.com (one-time setup)

The GitHub Actions workflow ([`.github/workflows/refresh.yml`](../.github/workflows/refresh.yml))
renders the site and deploys it to Vercel. It needs three secrets, and the domain
needs one DNS record. Do these once; after that everything is automatic.

Everything below uses tools you already have (`node`/`npx`, `gh`). You do **not**
need R or Quarto locally.

---

## 1. Create the Vercel project (CLI-only)

From the repo root:

```bash
npx vercel login          # opens a browser to authenticate
npx vercel link           # create / link a project
```

When `vercel link` prompts:

- **Set up and deploy?** → it's fine to link without deploying; choose to link.
- **Which scope?** → your personal account (or team).
- **Link to existing project?** → **No**, create a new one.
- **Project name?** → e.g. `mariners`.
- **Directory with your code?** → `./`

This writes `.vercel/project.json` (git-ignored) containing the two IDs you need.
Read them:

```bash
cat .vercel/project.json
# { "orgId": "team_or_user_xxx", "projectId": "prj_xxx" }
```

> Keep it CLI-only — do **not** connect the project to the GitHub repo in the
> Vercel dashboard. Vercel can't run R, so a Git-triggered build would fail; our
> Action is the only thing that should deploy.

## 2. Create a Vercel token

Go to **https://vercel.com/account/tokens**, create a token (scope: your account;
no expiry, or rotate as you like). Copy it.

## 3. Add the three GitHub secrets

These commands prompt for the value and never echo it. Run from the repo root:

```bash
gh secret set VERCEL_TOKEN                       # paste the token from step 2
gh secret set VERCEL_ORG_ID                      # paste "orgId" from step 1
gh secret set VERCEL_PROJECT_ID                  # paste "projectId" from step 1
```

Verify:

```bash
gh secret list
# VERCEL_ORG_ID, VERCEL_PROJECT_ID, VERCEL_TOKEN
```

## 4. First deploy

Trigger the workflow manually with `force` so it deploys regardless of the
game/data guards:

```bash
gh workflow run "Refresh Mariners site" -f force=true
gh run watch
```

When it finishes, the **Deploy** step logs a `*.vercel.app` URL — open it to
confirm the site looks right.

---

## 5. Add the custom domain

1. In the Vercel dashboard: **your project → Settings → Domains → Add Domain** and
   enter `mariners.bsnel.com`.
2. Vercel will say it's a subdomain and show a **CNAME target** — something like
   `xxxxxxxxxxxxxxxx.vercel-dns-017.com`. **Copy that exact value** (don't assume
   the old generic `cname.vercel-dns.com`).

## 6. Add the CNAME at GoDaddy

DNS stays at GoDaddy — **no domain transfer, no nameserver change.**

1. GoDaddy → **My Products → bsnel.com → DNS** (Manage DNS).
2. **Add** a record:
   - **Type:** `CNAME`
   - **Name / Host:** `mariners`   (just the label, not the full domain)
   - **Value / Points to:** the exact target Vercel showed in step 5
   - **TTL:** default (1 hour) is fine
3. Save.

Back in Vercel, the domain status flips to valid once DNS resolves (usually
minutes, up to the old record's TTL). Vercel auto-provisions the HTTPS certificate
via Let's Encrypt — nothing to do there.

Confirm:

```bash
dig +short mariners.bsnel.com        # should show the vercel-dns target / Vercel IPs
curl -sI https://mariners.bsnel.com  # 200, with a "server: Vercel" header
```

---

## How updates work after setup

- The workflow runs every morning (UTC `17 13` and `17 15` ≈ 6:17 & 8:17 AM PT).
- It only deploys if the Mariners finished a game in the last day **and** the live
  stat fetch succeeded; otherwise it skips and the last published site stays up.
- Force a refresh anytime: `gh workflow run "Refresh Mariners site" -f force=true`.

## Maintenance notes

- **60-day idle disable:** GitHub disables scheduled workflows after 60 days with no
  repo activity. The morning runs count as activity during the season; in the
  off-season, a single manual run (or any push) re-arms it.
- **Rotating the token:** create a new one and `gh secret set VERCEL_TOKEN` again.
- **Synthetic-data skips:** if you see repeated "deploy skipped — synthetic data"
  notices, FanGraphs is likely blocking the CI IP. The fix is to switch
  `R/01_fetch_data.R`'s primary source to the MLB Stats API (a follow-up, not
  required for the site to work).
