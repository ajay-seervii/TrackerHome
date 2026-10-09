# SQL Guide

How to set things up with SQL in the Supabase **SQL Editor** (Dashboard → SQL Editor → New query). Paste one block, change the values in quotes, and press **Run**.

Everything here can also be done on the website; see [PORTAL_GUIDE.md](PORTAL_GUIDE.md).

Values used in the examples:

| Placeholder | Meaning |
|---|---|
| `raanginrajasthan@gmail.com` | You, the site admin and owner |
| `reading` | The new tracker's short name (slug): lowercase letters, numbers and dashes |
| `friend@gmail.com` | An adult who uses the site on their own |
| `arjun@gmail.com` | A child whose ticks you approve |
| `Asia/Kolkata` | Time zone, used to count streak days and reset daily/weekly tasks |

---

## 1. Create a new project (tracker) with tasks

### Step 1: create the tracker

```sql
select pt__seed_tracker(
  'reading',                       -- slug (used in the link: pages/tracker.html?t=reading)
  'Reading Habit',                 -- name
  'Read 12 books this year',       -- description
  'raanginrajasthan@gmail.com',    -- owner email (must already be approved)
  'checklist',                     -- layout: checklist, timeline or quest
  'minimal',                       -- theme: minimal, rpg, neon, ocean, forest or candy
  'book',                          -- icon (list below)
  false                            -- needs approval? false for yourself
);
```

Icons: `target`, `gamepad`, `briefcase`, `book`, `star`, `heart`, `code`, `trophy`, `zap`, `users`, `sun`, `music`, `dumbbell`, `globe`, `tree`, `home`.

Running it again does nothing if the slug already exists.

### Step 2: add groups

A group holds tasks. `kind` can be `phase`, `week` or `section`; they look the same in the checklist layout. In the **timeline** layout, give groups a `week_number`. In the **quest** layout, each top-level group is a chapter.

```sql
insert into tasks (tracker_id, kind, title, sort_order)
select id, 'section', v.title, v.ord
from trackers, (values ('Every day', 10), ('Book 1', 20), ('Book 2', 30)) v(title, ord)
where slug = 'reading';
```

For a timeline, add weeks instead:

```sql
insert into tasks (tracker_id, kind, title, week_number, time_estimate, sort_order)
select id, 'week', v.title, v.week, v.est, v.week * 10
from trackers, (values
    ('Pick and start', 1, '2 hrs'),
    ('Keep going',     2, '3 hrs')
  ) v(title, week, est)
where slug = 'reading';
```

### Step 3: add tasks inside a group

`repeat`:
- `none` means tick once.
- `daily` resets every day.
- `weekly` resets every Monday.

```sql
insert into tasks (tracker_id, parent_id, kind, title, xp, difficulty, repeat, sort_order)
select g.tracker_id, g.id, 'task', v.title, v.xp, v.difficulty, v.rep, v.ord
from tasks g
join trackers t on t.id = g.tracker_id and t.slug = 'reading'
cross join (values
    ('Read for 20 minutes',   10, 'easy',   'daily',  10),
    ('Write one note',         5, 'easy',   'daily',  20),
    ('Visit the library',     20, 'medium', 'weekly', 30)
  ) v(title, xp, difficulty, rep, ord)
where g.title = 'Every day';
```

Change `'Every day'` to the group's title to fill another group. A task with no group:

```sql
insert into tasks (tracker_id, kind, title, xp, difficulty, sort_order)
select id, 'task', 'Join a book club', 25, 'medium', 5 from trackers where slug = 'reading';
```

A milestone line between groups (shown as a milestone banner in the timeline layout):

```sql
insert into tasks (tracker_id, kind, title, week_number, sort_order)
select id, 'divider', 'Milestone: first book finished', 2, 25 from trackers where slug = 'reading';
```

### Step 4: add a link to a group or task

```sql
insert into task_resources (task_id, title, url, sort_order)
select g.id, 'Goodreads', 'https://www.goodreads.com/', 10
from tasks g join trackers t on t.id = g.tracker_id and t.slug = 'reading'
where g.title = 'Book 1';
```

### Change the look later

```sql
update trackers set layout = 'quest', theme = 'forest' where slug = 'reading';
```

---

## 2. Add a standalone user

A standalone user ticks their own tasks and gets XP with no review. You can add them before or after their first sign-in.

### A. They have not signed in yet: save an invite

They are approved automatically the first time they press **Sign in with Google** with this email. The `grants` part gives them access to existing trackers. Leave it out to give no access.

```sql
insert into invites (email, display_name, timezone, grants)
values (
  'friend@gmail.com', 'Friend', 'Asia/Kolkata',
  jsonb_build_array(
    jsonb_build_object('tracker_id', (select id from trackers where slug = 'reading'), 'level', 'write')
  )
);
```

`level` can be `read` (can view only), `write` (can tick tasks) or `review` (approves other people's ticks; only on trackers that need approval).

### B. They have already tried to sign in

They saw "Waiting for approval". Approve them:

```sql
select pt_admin_approve_user('friend@gmail.com', 'Friend', 'Asia/Kolkata');
```

### Give them their own tracker

Once they are approved (after their first sign-in), create a tracker they own. They can then add tasks and create more trackers themselves from the Manage page:

```sql
select pt__seed_tracker('friend-fitness', 'Friend''s Fitness', 'Get fit in 2026',
  'friend@gmail.com', 'checklist', 'neon', 'dumbbell', false);
```

Or give them access to one of your trackers:

```sql
select pt_admin_grant('reading', 'friend@gmail.com', 'member', true);   -- true = can tick, false = view only
```

---

## 3. Add a user whose tasks need approval

This is for a child: they tick tasks and earn XP and badges straight away. Their XP shows as **pending review** until you check it.
- **Approve**: the XP is confirmed.
- **Reject**: the XP, and any badge or streak day that depended on it, is removed. Your reason is shown on the task, and the child can tick it again.

### Step 1: create a tracker that needs approval

The last argument `true` means needs approval. You, the owner, automatically become its **reviewer**.

```sql
select pt__seed_tracker('arjun-goals', 'Arjun''s Goals', 'Homework, reading and chores',
  'raanginrajasthan@gmail.com', 'quest', 'candy', 'star', true);
```

Add tasks as in section 1 (use `'arjun-goals'` as the slug).

### Step 2: add the child

Not signed in yet: save an invite with **write** access:

```sql
insert into invites (email, display_name, timezone, grants)
values (
  'arjun@gmail.com', 'Arjun', 'Asia/Kolkata',
  jsonb_build_array(
    jsonb_build_object('tracker_id', (select id from trackers where slug = 'arjun-goals'), 'level', 'write')
  )
);
```

Already signed in: approve and grant:

```sql
select pt_admin_approve_user('arjun@gmail.com', 'Arjun', 'Asia/Kolkata');
select pt_admin_grant('arjun-goals', 'arjun@gmail.com', 'member', true);
```

### Step 3 (optional): add another reviewer, e.g. the other parent

They must be approved first (section 2):

```sql
select pt_admin_grant('arjun-goals', 'partner@gmail.com', 'guardian');
```

### Reviewing

Reviews are done on the website. The **Home** page shows "Waiting for your approval" with Approve and Reject buttons. To see what is waiting from SQL:

```sql
select u.display_name, k.title, tp.awarded_xp, tp.completed_at
from task_progress tp
join tasks k on k.id = tp.task_id
join users u on u.id = tp.user_id
where tp.status = 'pending'
order by tp.completed_at;
```

---

## 4. Other useful commands

Who is approved, and who is admin:

```sql
select email, display_name, is_admin from users order by email;
```

Invites not used yet:

```sql
select email, display_name, created_at from invites where accepted_at is null;
```

Cancel an invite:

```sql
delete from invites where email = 'friend@gmail.com' and accepted_at is null;
```

Remove a person. They lose access to everything; their XP history is kept if you add them again:

```sql
delete from tracker_access where user_id = (select id from users where email = 'friend@gmail.com');
delete from users where email = 'friend@gmail.com';
```

Make someone else a site admin:

```sql
update users set is_admin = true where email = 'partner@gmail.com';
```

Delete the sample trackers (their ticks and XP go too):

```sql
delete from trackers where slug like 'sample-%';
```

Delete one of your own trackers completely:

```sql
delete from trackers where slug = 'reading';
```

More examples (badges, archiving tasks, changing XP) are in the cookbook at the bottom of `db/seed.sql`.
