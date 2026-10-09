# Pivot Tracker - Project Context

> Reference for every tracker in this repo: the home page, the Godot tracker, the 12-week career tracker, and any new trackers (for example, a child's goals).

---

## Overview

**Goal:** Gamify life progress. Every tracker awards XP; XP from all trackers adds up to a Life Level shown on the home page.

**Stack:**
- Frontend: static HTML pages, no build step
- Backend: Supabase (PostgreSQL, row level security, database functions)
- Auth: Google sign-in through Supabase, one session shared by all pages
- Storage: online only; progress is never saved in the browser
- Hosting: GitHub Pages (or any static host)

---

## File Structure

```
Pivot-Tracker/
├── index.html           # Home: sign in, Life Level, streak, trackers, approvals, activity
├── godot_plan.html      # Godot tracker (levels, achievements, skills)
├── 3month_plan.html     # 12-week career tracker (months, weeks, sections, resources)
├── tracker.html         # Generic tracker page: tracker.html?t=<slug>
├── admin.html           # Manage tasks (tracker creators only)
├── app.js               # Shared Supabase client, auth, SVG icons, data helpers
├── app.css              # Shared nav bar, sign-in gate, toasts, buttons
├── supabase-setup.sql   # Repeatable schema, policies, functions, seeds
└── GODOT_TRACKER_CONTEXT.md
```

All icons are inline SVG from the set in `app.js` (`PT.icon(name)`). Do not use emoji.

---

## Configuration

Project: ToDoTrackers (`uxoijaioqqnoncdmuefi`, ap-south-1). URL: `https://uxoijaioqqnoncdmuefi.supabase.co`.

Public Supabase values live at the top of `app.js` (`CONFIG`). Only the publishable/anon key belongs there; security comes from RLS and the database functions.

In Supabase:
1. Authentication → Providers → enable Google.
2. Authentication → URL Configuration → add every place the site runs, pointing at `index.html`, for example:
   - `http://localhost:8000/index.html`
   - `https://<user>.github.io/<repo>/index.html`

---

## Setup

1. Back up the database (Database → Backups, or export the tables).
2. Open SQL Editor and run all of `supabase-setup.sql`. It is safe to run again later.
3. Sign in once on the home page, then follow STEP 2 at the bottom of the SQL file:
   - `pt_admin_approve_user` - approve an account
   - `pt_admin_link_tracker` - attach an existing tracker (keeps its progress)
   - `pt_admin_create_tracker` - create a new tracker
   - `pt_admin_seed` - add the built-in Godot or career task lists
   - `pt_admin_migrate_legacy` - move old Godot progress into per-task rows
   - `pt_admin_grant` - give someone access to a tracker

The `pt_admin_*` functions can only be run from the SQL Editor, not from the browser.

### Adding a tracker for a child
```sql
select pt_admin_approve_user('child@example.com', 'Arjun', 'Asia/Kolkata');
select pt_admin_create_tracker('arjun-goals', 'Arjun''s Goals', 'Homework, reading and chores',
  'you@example.com', 'standard', null, 'star', true, true);
select pt_admin_grant('arjun-goals', 'child@example.com', 'member');
```
Then add tasks on the Manage tasks page. The child opens it from their home page; you approve their completions from yours.

---

## How It Works

### Sign in
1. Home page → "Sign in with Google".
2. Supabase returns to `index.html`; the session is stored once and shared by every page.
3. `pt_me()` checks the account is in `users` (approved). Unapproved accounts see "Waiting for approval".
4. Planner pages call `PT.requireAuth()`. Signed-out visitors are sent to home and returned afterwards.
5. Every page shows Home and Sign out. Signing out in one tab signs out the others.

### Completing a task
```
Tick task → pt_complete_task(task) → checks access → task_progress row
  → (approval needed?) pending : approved + xp_events row (+ Godot level/achievements)
  → page updates; Life Level on home is the sum of xp_events
```

- Unchecking (`pt_uncomplete_task`) removes the row and adds a negative `refund` event for the XP originally awarded. Godot does not allow unchecking.
- Changing a task's XP later only affects future completions.
- Saving needs a connection; offline, the controls are disabled.

### Approvals
On trackers with `requires_approval`, a `member`'s ticks are `pending` and give no XP. A `guardian` sees them on the home page and approves or rejects. Streak days use the day the task was done, not the day it was approved.

### Life Level
XP needed to go from level N to N+1 is `round(100 × N^1.5)`: 100, 283, 520, 800, 1118, ... Level is calculated from total XP and never stored.

---

## Database Schema

| Table | Purpose |
|---|---|
| `users` | Approved accounts: email, display name, time zone |
| `trackers` | name, slug, page, icon, `ruleset` (`standard`/`godot`), `requires_approval`, `allow_uncheck`, `created_by` |
| `tracker_access` | user × tracker with `role`: `owner`, `member`, `guardian` |
| `tasks` | Task definitions and groups (see below) |
| `task_resources` | Links attached to a group or task |
| `task_progress` | One row per user × task: `pending`, `approved` or `rejected`, awarded XP |
| `xp_events` | Append-only XP ledger; Life XP, activity feed and tracker XP are sums of it |
| `progress` | Godot level, current XP, total XP, achievements, skills. Old completion arrays kept as backup |

### tasks
| Column | Meaning |
|---|---|
| `id` | Permanent ID, unchanged by renames or moves |
| `tracker_id` | Owning tracker |
| `parent_id` | Containing phase, week or section |
| `kind` | `phase`, `week`, `section`, `task`, `divider` |
| `title`, `description` | Text |
| `xp` | XP for completing (tasks only) |
| `difficulty` | `easy`, `medium`, `hard` or empty |
| `week_number` | Plan week; children inherit their parent's week |
| `month_number` | Calculated from week (weeks 1-4 = month 1) |
| `time_estimate` | For weeks, e.g. "12-14 hrs" |
| `sort_order` | Position among siblings |
| `archived_at` | Hidden but history kept |
| `seed_key`, `legacy_key` | Built-in seed identity and old browser IDs |

Only `task` rows get checkboxes, award XP, and count toward completion.

### Access rules
- Only approved users can read anything.
- Access to a tracker comes from `tracker_access`; progress can only be changed for yourself, through the `pt_*` functions.
- Only the tracker's creator can edit tasks, resources and tracker settings.
- Guardians can read and review members' completions; they have no progress of their own on that tracker.

---

## Gamification System

### Life Level (home page)
Sum of every XP event across all trackers, using the curve above. The streak counts consecutive days (in the user's time zone) with at least one approved task.

### Godot tracker (`ruleset = 'godot'`)
These rules are unchanged from the original page and now run in the database (`pt__godot_apply`).

- Level N needs N × 100 XP; on level up the leftover XP carries into the next level.
- Tasks are complete-once (no unchecking).

**Phases:**
1. Setup & Foundations (4 tasks, 75 XP)
2. Player Control (4 tasks, 100 XP)
3. Combat System (5 tasks, 160 XP)
4. Menu & State System (4 tasks, 115 XP)
5. Polish (4 tasks, 105 XP)
6. Optional Features (4 tasks, 140 XP)

**Total: 25 tasks, 695 XP**

### Achievements (6 total)
Unlock via conditions:

| Name | Condition | XP |
|------|-----------|-----|
| Started | 3+ tasks done | 50 |
| Player | Complete "Player Control" phase | 50 |
| Combat | Complete "Combat System" phase | 100 |
| Polish | Complete "Polish" phase | 100 |
| Quarter | Reach 25% project completion | 50 |
| Master | 100% project completion | 200 |

### Skills (3 total, claimable at XP thresholds)
- 2x XP Week (300 XP) — +2x multiplier next week
- Focus Bonus (500 XP) — +25% XP on consistency
- Debug Mode (1000 XP) — Advanced tracking tools

Skills are cosmetic for now; the multipliers are not applied.

### 12-week career tracker
- 12 weeks, 68 tasks, grouped into 3 months (weeks 1-4, 5-8, 9-12).
- Default XP by difficulty: easy 15, medium 25, hard 40 (editable per task).
- Tasks can be unchecked; the XP originally awarded is refunded.

### Other trackers
Use `tracker.html?t=<slug>`. Any mix of phases, weeks, sections and tasks is shown as collapsible groups.

---

## Design

- All icons are inline SVG from `app.js`; no emoji.
- Each page keeps its own look and sets `--pt-*` CSS variables so the shared nav, gate and toasts match:
  - Godot: dark vaporwave (`#0a0e27`, cyan/pink accents)
  - Career: warm light (`#f5f1e8`, green accent)
  - Home: warm light; generic tracker: light with violet accent; admin: neutral

---

## Shared Helpers (`app.js`, global `PT`)

```js
PT.requireAuth()             // Gate a page; redirect to home if signed out
PT.signIn(next) / PT.signOut()
PT.mountNav(target, opts)    // Home link, user name, offline badge, Sign out
PT.loadTracker(slug)         // Tracker, role, task tree, progress, tracker XP
PT.completeTask(id) / PT.uncompleteTask(id)
PT.resetTracker(id) / PT.importCompletions(id, keys)
PT.lifeLevel(xp)             // { level, into, needed, pct }
PT.icon(name) / PT.iconEl(name) / PT.hydrateIcons()
PT.toast(message, 'error'?)
```

### Database functions callable from the browser
`pt_me`, `pt_dashboard`, `pt_complete_task`, `pt_uncomplete_task`, `pt_review_completion`, `pt_godot_unlock_skill`, `pt_reset_tracker`, `pt_import_completions`.

---

## Local Testing

Google sign-in needs an http(s) address, not a file opened directly.

```bash
cd Pivot-Tracker
python -m http.server 8000
# open http://localhost:8000/index.html
```

Add `http://localhost:8000/index.html` to Supabase redirect URLs.

## Deployment
Push the folder to a GitHub repo and enable Pages (Settings → Pages → main branch). Add `https://<user>.github.io/<repo>/index.html` to Supabase redirect URLs.

---

## Testing Checklist

- [ ] Run `supabase-setup.sql` twice; the second run makes no changes to data
- [ ] Seed counts: Godot 25 tasks / 695 XP, career 68 tasks
- [ ] Godot level, XP and achievements match what they were before migration
- [ ] Home: sign in → Life Level, streak, tracker cards, activity show
- [ ] Open each planner from home; no second sign-in; Home and Sign out visible
- [ ] Open a planner URL directly while signed out → home → back to the planner after sign-in
- [ ] Sign out in one tab → other tabs return to home
- [ ] Unapproved account sees "Waiting for approval" and no data
- [ ] Career: tick → +XP; untick → same XP removed, even after editing the task's XP
- [ ] Godot: tick → XP, level up and achievements as before; cannot untick
- [ ] Child tracker: child's tick is pending with no XP; approve on home → XP appears for the child
- [ ] Manage tasks: add, edit, move, archive, restore, add links; changes show on the tracker
- [ ] Non-creator opening `admin.html` cannot edit anything
- [ ] Go offline → checkboxes disabled and "Offline" shown
- [ ] Import from this browser twice → second time imports nothing new

---

## Troubleshooting

### "Waiting for approval" after sign-in
Run `select pt_admin_approve_user('email', 'Name', 'Time/Zone');` in the SQL Editor.

### "This tracker was not found"
The tracker needs a slug (`godot`, `career-pivot`) and a `tracker_access` row for you. See STEP 2 in the SQL file.

### Sign-in returns to the wrong page or fails
Check Authentication → URL Configuration contains the exact `index.html` URL you are using.

### Unknown task IDs after migration
`pt_admin_migrate_legacy` reports old IDs it could not match. They stay in `progress.completed_tasks`; add matching tasks with that `legacy_key`, or ignore them.

---

## Notes

- Email: ajay.kc@prodapt.com
- GitHub: ajay-seervii
- Career goal: 12-week pivot to Cloud & AI/ML
