# TrackerHome - Project Context

> Reference for every tracker in this repo: the home page, the shared tracker page with its layouts and themes, the Manage page, and the database.
>
> How-to guides: [SQL_GUIDE.md](SQL_GUIDE.md) (do things in the Supabase SQL Editor) and [PORTAL_GUIDE.md](PORTAL_GUIDE.md) (do the same on the website).

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
├── index.html              # Home: sign in, Life Level, streak, quests, trackers, badges, approvals
├── pages/
│   ├── tracker.html        # Every tracker: pages/tracker.html?t=<slug>, drawn by its layout + theme
│   └── admin.html          # Manage: tasks, access, settings, new tracker, people (admin)
├── assets/
│   ├── css/app.css         # Shared nav, settings sheet, sign-in gate, toasts, buttons
│   ├── css/themes.css      # Tracker themes: minimal, rpg, neon, ocean, forest, candy
│   └── js/app.js           # Shared Supabase client, auth, SVG icons, themes/layouts, data helpers
├── db/
│   ├── schema.sql          # DDL: tables, constraints, functions, security (re-runnable)
│   └── seed.sql            # DML: owner, trackers, badges, task lists, samples, cookbook (re-runnable)
└── docs/
    ├── PROJECT_CONTEXT.md  # This file
    ├── SQL_GUIDE.md        # How-to in SQL
    └── PORTAL_GUIDE.md     # How-to on the website
```

`index.html` stays at the root because GitHub Pages serves it as the site's home. `trackers.page` is only for a custom page inside `pages/`; leave it empty to use `tracker.html`.

All icons are inline SVG from the set in `assets/js/app.js` (`PT.icon(name)`). Do not use emoji.

---

## Configuration

Project: ToDoTrackers (`uxoijaioqqnoncdmuefi`, ap-south-1). URL: `https://uxoijaioqqnoncdmuefi.supabase.co`.

Public Supabase values live at the top of `assets/js/app.js` (`CONFIG`). Only the publishable/anon key belongs there; security comes from RLS and the database functions.

In Supabase:
1. Authentication → Providers → enable Google.
2. Authentication → URL Configuration → add every place the site runs, pointing at `index.html`, for example:
   - `http://localhost:8000/index.html`
   - `https://<user>.github.io/<repo>/index.html`

---

## Setup

1. Back up the database (Database → Backups, or export the tables).
2. Sign in once on the home page so your account exists.
3. In the SQL Editor run `db/schema.sql`, then `db/seed.sql`. Both are safe to run again; seeding never overwrites rows you edited.
4. Optional one-off commands are listed at the bottom of `db/seed.sql`; step-by-step versions are in [SQL_GUIDE.md](SQL_GUIDE.md).

The owner account in `db/seed.sql` is the **site admin** (`users.is_admin`). The admin adds people on the Manage page (People tab); tracker owners set access per tracker (Access tab). The `pt_admin_*` and `pt__*` functions can only be run from the SQL Editor, not from the browser.

### Adding a tracker for a child
Manage → **New tracker** → tick **Needs approval** → People tab → add the child's Google email with **Read & write** on that tracker. Details: [PORTAL_GUIDE.md](PORTAL_GUIDE.md#3-add-a-child-whose-ticks-you-approve), or in SQL: [SQL_GUIDE.md](SQL_GUIDE.md#3-add-a-user-whose-tasks-need-approval).

---

## How It Works

### Sign in
1. Home page → "Sign in with Google".
2. Supabase returns to `index.html`; the session is stored once and shared by every page.
3. `pt_me()` checks the account is in `users` (approved). If it is not, but the site admin saved an invite for this verified email, the account is approved and given the invited tracker access on the spot. Otherwise it sees "Waiting for approval".
4. Other pages call `PT.requireAuth()`. Signed-out visitors are sent to home and returned afterwards.
5. Every page has the settings button (top right) with Home, Manage and Sign out. Signing out in one tab signs out the others.

### Completing a task
```
Tick task → pt_complete_task(task) → checks access → task_progress row for the current period
  → XP is added to xp_events now (+ Godot level/achievements)
  → status: pending (member on an approval tracker) or approved
  → page updates; Life Level on home is the sum of xp_events
```

- Unchecking (`pt_uncomplete_task`) removes the row and adds a negative `refund` event for the XP originally awarded. Godot does not allow unchecking.
- Changing a task's XP later only affects future completions.
- Saving needs a connection; offline, the controls are disabled.

### Repeating tasks
`tasks.repeat` is `none`, `daily` or `weekly`. Each completion is stored with a `period_key`: `once`, `d:<date>` or `w:<Monday>` in the user's time zone. A daily task can be ticked (and earn XP) once per day, a weekly task once per week (Monday to Sunday). Unticking only affects the current day/week. "Done" and percentages use the current period. Godot tasks are always complete-once.

### Approvals
On trackers with `requires_approval`, a `member`'s tick gives XP **straight away** but is marked `pending`. Everywhere it shows it is labelled "pending review": the task row, the toast, the tracker summary, the home XP bar (striped part), tracker cards and badges unlocked only through pending ticks.

The `guardian` (reviewer) sees it on the home page:
- **Approve**: marks it approved; no extra XP.
- **Reject** (optional reason, shown to the member): marks it rejected and adds a negative `rejected` XP event, so XP, streak days and badges that depended on it go away. The member can tick it again.

When the member next opens home they get a message for each review ("Approved: +25 XP is now confirmed" / "Sent back: -25 XP") and for badges earned or lost. Streak days use the day the task was done. The Godot ruleset cannot require approval.

### Life Level
XP needed to go from level N to N+1 is `round(100 × N^1.5)`: 100, 283, 520, 800, 1118, ... Level is calculated from total XP and never stored.

---

## Database Schema

| Table | Purpose |
|---|---|
| `users` | Approved accounts: email, display name, time zone, `is_admin` (site admin) |
| `trackers` | name, slug, page, icon, `layout`, `theme`, `ruleset` (`standard`/`godot`), `requires_approval`, `allow_uncheck`, `created_by` |
| `tracker_access` | user × tracker with `role`: `owner`, `member`, `guardian` |
| `tasks` | Task definitions and groups (see below) |
| `task_resources` | Links attached to a group or task |
| `task_progress` | One row per user × task × period: `pending`, `approved` or `rejected`, awarded XP, `review_note` |
| `xp_events` | Append-only XP ledger; Life XP, activity feed and tracker XP are sums of it |
| `invites` | People the admin added before their first sign-in, with the tracker access to give them |
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
| `repeat` | `none`, `daily` or `weekly` (tasks only) |
| `sort_order` | Position among siblings |
| `archived_at` | Hidden but history kept |
| `seed_key`, `legacy_key` | Built-in seed identity and old browser IDs |

Only `task` rows get checkboxes, award XP, and count toward completion.

### Access rules
- Only approved users can read anything.
- Access to a tracker comes from `tracker_access`; progress can only be changed for yourself, through the `pt_*` functions.
- Only the tracker's creator can edit tasks, resources and tracker settings (including layout and theme).
- Guardians can read and review members' completions; they have no progress of their own on that tracker.
- Tracker owners and the site admin can create trackers (`pt_create_tracker`); members cannot.
- Only the site admin can add, approve or remove people (`pt_people_list`, `pt_invite_user`, `pt_approve_signup`, `pt_revoke_invite`, `pt_remove_user`). Other owners only see people who already share a tracker with them.

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
- Timeline layout, minimal theme.
- 12 weeks, 68 tasks, grouped into 3 months (weeks 1-4, 5-8, 9-12).
- Default XP by difficulty: easy 15, medium 25, hard 40 (editable per task).
- Tasks can be unchecked; the XP originally awarded is refunded.

---

## Layouts and Themes

Every tracker opens in `pages/tracker.html?t=<slug>`. Two settings (Manage → Settings) decide how it looks:

| Layout | Shows | Structure it expects |
|---|---|---|
| `checklist` | Collapsible groups with progress counts | Any mix of groups and tasks |
| `timeline` | Month tabs, week cards (number, time estimate, progress), milestones | Groups with a Week number; dividers become milestones; items without a week show above the tabs |
| `quest` | Level ring, rank, chapters with progress and "Cleared" tags, side quests | Each top-level group is a chapter; top-level tasks are side quests. Godot also shows achievements and skills |

Themes (`assets/css/themes.css`): `minimal`, `rpg`, `neon`, `ocean`, `forest`, `candy`. A theme is a block of CSS variables plus a few flourishes; to add one, copy a block, rename it, and add it to `THEMES` in `assets/js/app.js`. Unknown theme names show as minimal.

### Templates
Manage → New tracker → **Start from** copies another tracker's groups, tasks, repeats and links (not anyone's progress). The copy is independent of the original.

### Sample trackers
`db/seed.sql` adds six `sample-*` trackers owned by the site admin, one for each layout and several themes:

| Slug | Layout | Theme |
|---|---|---|
| `sample-morning-routine` | checklist | candy (daily tasks) |
| `sample-fitness-30` | checklist | neon (daily, weekly and one-off) |
| `sample-learn-spanish` | timeline | ocean |
| `sample-treehouse` | quest | forest |
| `sample-guitar-quest` | quest | rpg |
| `sample-weekly-chores` | checklist | minimal (weekly tasks) |

Delete them all with `delete from trackers where slug like 'sample-%';` (re-running `db/seed.sql` adds them back).

---

## Design

- All icons are inline SVG from `assets/js/app.js`; no emoji.
- Home and Manage use a dark game look. Tracker pages use the tracker's theme; each theme sets the `--pt-*` CSS variables so the shared nav, gate and toasts match.
- XP waiting for review is always shown with a clock icon and yellow stripes.

---

## Shared Helpers (`assets/js/app.js`, global `PT`)

```js
PT.requireAuth()             // Gate a page; redirect to home if signed out
PT.signIn(next) / PT.signOut()
PT.mountNav(target, opts)    // Home link or brand, offline badge, settings button
PT.loadTracker(slug)         // Tracker (with layout/theme), role, task tree, current-period progress, XP, pending XP
PT.completeTask(id) / PT.uncompleteTask(id)
PT.announceCompletion(res)   // "+25 XP" or "+25 XP, waiting for review" toast
PT.resetTracker(id) / PT.importCompletions(id, keys)
PT.lifeLevel(xp) / PT.rankFor(level)
PT.periodKey(repeat, tz)     // Same period rule as the database
PT.THEMES / PT.LAYOUTS / PT.TRACKER_ICONS
PT.icon(name) / PT.iconEl(name) / PT.hydrateIcons()
PT.toast(message, 'error' | 'pending' | 'reward'?)
```

### Database functions callable from the browser
`pt_me`, `pt_dashboard`, `pt_complete_task`, `pt_uncomplete_task`, `pt_review_completion`, `pt_godot_unlock_skill`, `pt_reset_tracker`, `pt_import_completions`, `pt_manage_access`, `pt_manage_set_access`, `pt_create_tracker`, and for the site admin `pt_people_list`, `pt_invite_user`, `pt_revoke_invite`, `pt_approve_signup`, `pt_remove_user`.

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

- [ ] Run `db/schema.sql` and `db/seed.sql` twice; the second run makes no changes to data
- [ ] Seed counts: Godot 25 tasks / 695 XP, career 68 tasks
- [ ] Godot level, XP and achievements match what they were before migration
- [ ] Home: sign in → Life Level, streak, tracker cards, activity show
- [ ] Open each planner from home; no second sign-in; Home and Sign out visible
- [ ] Open a planner URL directly while signed out → home → back to the planner after sign-in
- [ ] Sign out in one tab → other tabs return to home
- [ ] Unapproved account sees "Waiting for approval" and no data
- [ ] Career: tick → +XP; untick → same XP removed, even after editing the task's XP
- [ ] Godot: tick → XP, level up and achievements as before; cannot untick
- [ ] Child tracker: child's tick gives XP at once, shown as pending; reject with a reason → XP and dependent badges go, reason shows on the task; approve → no extra XP, "confirmed" message for the child
- [ ] Daily task: tick today → XP; tomorrow it is unticked and can be earned again
- [ ] Each sample tracker shows its layout and theme on phone and desktop
- [ ] Manage: change layout/theme → tracker page changes after reload
- [ ] New tracker, empty and copied from a sample; editing the copy leaves the sample unchanged
- [ ] People tab (admin): add someone by email → they sign in and land with the right access; cancel an invite; remove a person
- [ ] Home links to Godot and the 12-week plan open `pages/tracker.html` (seed cleared their old `page` values)
- [ ] Manage tasks: add, edit, move, archive, restore, add links; changes show on the tracker
- [ ] Non-creator opening `pages/admin.html` cannot edit anything
- [ ] Go offline → checkboxes disabled and "Offline" shown
- [ ] Import from this browser twice → second time imports nothing new

---

## Troubleshooting

### "Waiting for approval" after sign-in
The site admin adds the email on Manage → People (it appears under "Signed in, waiting for approval"), or run `select pt_admin_approve_user('email', 'Name', 'Time/Zone');` in the SQL Editor.

### "This tracker was not found"
The tracker needs a slug (`godot`, `career-pivot`) and a `tracker_access` row for you. Run `db/seed.sql`, or give access on the Manage page.

### Sign-in returns to the wrong page or fails
Check Authentication → URL Configuration contains the exact `index.html` URL you are using.

### Unknown task IDs after migration
`pt_admin_migrate_legacy` reports old IDs it could not match. They stay in `progress.completed_tasks`; add matching tasks with that `legacy_key`, or ignore them.

---

## Notes

- Email: ajayace2@gmail.com
- GitHub: ajay-seervii
- Career goal: 12-week pivot to Cloud & AI/ML
