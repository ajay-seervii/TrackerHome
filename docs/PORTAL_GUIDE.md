# Portal Guide

How to do everything on the website. Open the site, sign in with Google, then press the **round avatar button at the top right** and choose **Manage**.

The same things can be done in SQL; see [SQL_GUIDE.md](SQL_GUIDE.md).

Who can do what:

| You are | You can |
|---|---|
| **Site admin** (the owner account) | Everything below, plus add and remove people (People tab) |
| **Tracker owner** | Create trackers, edit tasks, set access, change layout and theme for trackers you own |
| **Member** (for example a child) | Tick tasks on trackers shared with you; cannot create trackers |

---

## 1. Create a new tracker (project)

1. Manage → **New tracker**.
2. Fill in:
   - **Name** and an optional **Description**.
   - **Start from**:
     - **Empty tracker**, or
     - **Copy of …** any tracker you own. This copies its groups, tasks, repeats and links, but nobody's progress. The sample trackers make good templates.
   - **Layout**: how the tracker is arranged. The hint under the field explains each one:
     - **Checklist**: groups you can open and close.
     - **Timeline**: month tabs and week cards. Give groups a Week number.
     - **Quest**: a level bar and chapters. Each top-level group is a chapter.
   - **Theme**: Minimal, RPG, Neon, Ocean, Forest or Candy. The dot shows its colours.
   - **Icon**.
   - **Needs approval**: tick this for a child's tracker. See section 3.
3. Press **Create tracker**. It opens on the Tasks tab, ready for tasks.

Change the layout, theme, name or icon later on the **Settings** tab.

## 2. Add and organise tasks

On the **Tasks** tab:

1. **Add item** creates a top-level item. On a group, the **+** button adds an item inside it.
2. Choose the **Type**:
   - **Task**: something you tick, worth XP.
   - **Section**, **Week** or **Phase**: a group that holds tasks.
   - **Divider label**: a separator, shown as a milestone in the timeline layout.
3. For tasks, set:
   - **XP**: points earned per tick.
   - **Difficulty** (optional).
   - **Repeat**:
     - **Once**: tick it one time.
     - **Every day**: it resets each day and can earn XP again.
     - **Every week**: it resets every Monday.
4. For timeline trackers, give each week group a **Week** number and an optional **Time estimate**. Items inside a week take its week number.
5. Edit an existing item with the pencil button. Links can be added there under **Resource links**.
6. Reorder with the up and down arrows.
7. **Archive** hides an item but keeps earned XP. Tick **Show archived** to see it and **Restore** it.

Press **Open** next to the tracker picker to see how it looks.

## 3. Add a child whose ticks you approve

1. Create a tracker with **Needs approval** ticked (section 1). As its owner you automatically become its **Reviewer**.
2. Add the tasks (section 2).
3. Add the child as described in section 4, giving them **Read & write** on this tracker.

What the child sees:
- When they tick a task they get the XP **straight away**. It is marked **pending review** with a clock icon and yellow stripes: on the task, in the message, on their XP bar and on tracker cards. Badges unlocked only through pending ticks show a "pending" tag.

What you see:
- On your **Home** page, under **Waiting for your approval**:
  - **Approve**: the XP is confirmed. No extra XP is added.
  - **Reject**: type an optional reason and press **Send back**. The XP is removed, along with any badge or streak day that depended on it. The child sees "Sent back" and your reason on the task, and can tick it again when it is really done.
- The next time the child opens Home, they get a message for each review, and for any badge earned or lost.

To add another reviewer, for example the other parent, open the tracker's **Access** tab and choose **Reviewer** for them.

## 4. Add a person (site admin)

Manage → **People** tab → **Add a person**:

1. **Google email**: the address they will sign in with.
2. **Name** (optional) and **Time zone**. The time zone is used for streaks and for resetting daily and weekly tasks.
3. Under **Tracker access**, pick a level for each tracker:
   - **No access**: the tracker is hidden.
   - **Read only**: can look, cannot tick.
   - **Read & write**: can tick tasks and earn XP.
   - **Reviewer**: approves other people's ticks. Only offered on trackers that need approval.
4. Press **Add person**.
   - If they have already tried to sign in, they are added straight away.
   - Otherwise an invite is saved, and they are added automatically the first time they sign in with that Google email.

The People tab also lists:
- **Signed in, waiting for approval**: people who tried to sign in. Press **Approve**, then give them access on each tracker's **Access** tab.
- **Invited, not signed in yet**: use **Cancel invite** to withdraw an invite.
- **People**: everyone approved and which trackers they can use. **Remove** takes away all their access. Their XP history is kept if you add them again. People who own trackers cannot be removed here.

From any tracker's **Access** tab, **Add a new person** jumps to this form with that tracker already set to Read & write.

## 5. Change access for someone already added

Open the tracker → **Access** tab → choose **No access**, **Read only**, **Read & write** or **Reviewer** next to their name. Tracker owners who are not the site admin only see people who already share a tracker with them.

## 6. Using a tracker

- Open it from **Quest lines** on Home.
- Tick tasks to earn XP. Untick to take the XP back, except on Godot, where tasks are complete-once.
- The **options button** (three dots, top right of the tracker page) has:
  - **Export my progress**.
  - **Import from a file**.
  - **Import from this browser**: only shown if old offline progress is found.
  - **Manage this tracker**: owners only.
  - **Reset my progress**.

## 7. Sample trackers

Six trackers starting with "sample-" show every layout and several themes. Tick tasks in them freely. To remove them all, run this in the SQL Editor:

```sql
delete from trackers where slug like 'sample-%';
```

Running `db/seed.sql` again brings them back. To keep one as a starting point, make a copy with **New tracker → Start from** before deleting.
