-- =====================================================================
-- Pivot Tracker seed data (DML). Run after db/schema.sql.
-- Safe to re-run: existing rows, including your edits, are left alone.
-- Sign in on the home page once before the first run so your account exists.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Owner and trackers
-- ---------------------------------------------------------------------
do $$
declare
  owner_email text := 'raanginrajasthan@gmail.com';
begin
  perform public.pt_admin_approve_user(owner_email, null, 'Asia/Kolkata');

  perform public.pt_admin_create_tracker('godot', 'Godot Game', 'Hack & slash game in Godot 4 with C#',
    owner_email, 'godot', 'godot_plan.html', 'gamepad', false, false);

  perform public.pt_admin_create_tracker('career-pivot', '12-Week Career Pivot', 'Cloud & AI/ML · AI-200 Certification',
    owner_email, 'standard', '3month_plan.html', 'briefcase', false, true);
end $$;

-- Trackers created before the role column existed: creators become owners.
update public.tracker_access a set role = 'owner'
from public.trackers t
where t.id = a.tracker_id and t.created_by = a.user_id and a.role = 'member';

-- ---------------------------------------------------------------------
-- Badges
-- metric: tasks_done, best_streak, current_streak, level, life_xp, today_xp,
--         tracker_tasks_done, tracker_percent, tracker_xp (tracker_* need tracker_id)
-- ---------------------------------------------------------------------
insert into public.badges (slug, name, description, icon, metric, threshold, sort_order) values
  ('first-quest', 'First Quest', 'Finish 1 task', 'star', 'tasks_done', 1, 10),
  ('getting-going', 'Getting Going', 'Finish 10 tasks', 'check-circle', 'tasks_done', 10, 20),
  ('grinder', 'Grinder', 'Finish 50 tasks', 'zap', 'tasks_done', 50, 30),
  ('centurion', 'Centurion', 'Finish 100 tasks', 'trophy', 'tasks_done', 100, 40),
  ('on-fire', 'On Fire', '3-day streak', 'flame', 'best_streak', 3, 50),
  ('week-warrior', 'Week Warrior', '7-day streak', 'calendar', 'best_streak', 7, 60),
  ('unstoppable', 'Unstoppable', '30-day streak', 'rocket', 'best_streak', 30, 70),
  ('rising-star', 'Rising Star', 'Reach level 5', 'award', 'level', 5, 80),
  ('veteran', 'Veteran', 'Reach level 10', 'crown', 'level', 10, 90),
  ('thousand-club', 'Thousand Club', 'Earn 1,000 XP', 'sparkles', 'life_xp', 1000, 100)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------
-- Godot task list
-- ---------------------------------------------------------------------
do $$
declare
  tid uuid := (select id from public.trackers where slug = 'godot');
  r record;
begin
  if tid is null then
    raise exception 'Tracker godot not found';
  end if;
  for r in select * from (values
      ('setup', 'Setup & Foundations', 1), ('player', 'Player Control', 2), ('combat', 'Combat System', 3),
      ('menu', 'Menu & State System', 4), ('polish', 'Polish', 5), ('extra', 'Optional Features', 6)
    ) v(key, title, ord)
  loop
    perform public.pt__seed_node(tid, 'godot:phase:' || r.key, null, 'phase', r.title, 0, null, null, null, r.ord * 10, null);
  end loop;
  for r in select * from (values
      ('setup', 't1', 'Install Godot 4.x & .NET SDK', 15, 1),
      ('setup', 't2', 'Create new C# Godot project', 20, 2),
      ('setup', 't3', 'Set up project structure & Git', 25, 3),
      ('setup', 't4', 'First scene: empty 2D stage', 15, 4),
      ('player', 't5', 'Player sprite & animation setup', 25, 1),
      ('player', 't6', 'WASD movement controller', 30, 2),
      ('player', 't7', 'Camera follow player', 20, 3),
      ('player', 't8', 'Collision detection working', 25, 4),
      ('combat', 't9', 'Attack animation & slash hitbox', 35, 1),
      ('combat', 't10', 'Basic enemy prefab', 30, 2),
      ('combat', 't11', 'Enemy health & damage system', 30, 3),
      ('combat', 't12', 'Enemy knockback on hit', 25, 4),
      ('combat', 't13', 'Simple AI (walk + attack)', 40, 5),
      ('menu', 't14', 'Main menu with Play/Exit buttons', 30, 1),
      ('menu', 't14b', 'Animated background for menu', 25, 2),
      ('menu', 't14c', 'Save/Load game state system', 40, 3),
      ('menu', 't14d', 'Menu transitions & animations', 20, 4),
      ('polish', 't15', 'Health bar UI (player & enemies)', 25, 1),
      ('polish', 't16', 'Game over & restart', 20, 2),
      ('polish', 't17', 'Sound effects (attack, hit, death)', 30, 3),
      ('polish', 't18', 'Particle effects on slash', 30, 4),
      ('extra', 't19', 'Enemy spawner waves', 35, 1),
      ('extra', 't20', '2-3 attack combo system', 40, 2),
      ('extra', 't21', 'Simple score/wave system', 25, 3),
      ('extra', 't22', 'Enemy variety (2+ types)', 40, 4)
    ) v(phase, legacy, title, xp, ord)
  loop
    perform public.pt__seed_node(tid, 'godot:' || r.legacy, 'godot:phase:' || r.phase, 'task', r.title, r.xp, null, null, null, r.ord * 10, r.legacy);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 12-week career task list (XP: easy 15, medium 25, hard 40)
-- ---------------------------------------------------------------------
do $$
declare
  tid uuid := (select id from public.trackers where slug = 'career-pivot');
  r record;
begin
  if tid is null then
    raise exception 'Tracker career-pivot not found';
  end if;
  for r in select * from (values
      (1, 'Azure Refresh + Docker Setup', '12-14 hrs'),
      (2, 'Docker Deep Dive + Container Instances', '13-15 hrs'),
      (3, 'Project 1: Weather Pipeline (Build Phase)', '14-15 hrs'),
      (4, 'Project 1: Deploy + Blog', '12-14 hrs'),
      (5, 'Azure OpenAI + FastAPI Basics', '13-15 hrs'),
      (6, 'Project 2: Document Analyzer (Build Phase)', '14-15 hrs'),
      (7, 'Project 2: Deploy + Frontend', '14-15 hrs'),
      (8, 'AI-200 Exam Prep Sprint 1', '12-14 hrs'),
      (9, 'Azure ML + Model Training', '14-15 hrs'),
      (10, 'ML Pipeline Orchestration', '13-15 hrs'),
      (11, 'Project 3: Deploy + Monitoring', '14-15 hrs'),
      (12, 'AI-200 Exam Sprint 2 + Career Prep', '13-15 hrs')
    ) v(week, title, est)
  loop
    perform public.pt__seed_node(tid, 'career:w' || r.week, null, 'week', r.title, 0, null, r.week, r.est, r.week * 10, null);
    perform public.pt__seed_node(tid, 'career:w' || r.week || ':s0', 'career:w' || r.week, 'section', 'Tasks', 0, null, r.week, null, 10, null);
  end loop;
  for r in select * from (values
      (4, 'Phase 1 Complete: Project 1 Live on Azure'),
      (8, 'Phase 2 Complete: Project 2 Live + AI-200 Prep Started'),
      (12, 'Phase 3 Complete: All Projects Live + AI-200 Ready')
    ) v(week, title)
  loop
    perform public.pt__seed_node(tid, 'career:divider:' || r.week, null, 'divider', r.title, 0, null, r.week, null, r.week * 10 + 5, null);
  end loop;
  -- Legacy keys reproduce the old page's positional IDs: dividers occupied array slots 4, 9 and 14.
  for r in select * from (values
      (1, 0, 'Refresh: Azure Portal navigation, Resource Groups, Subscriptions', 'easy'),
      (1, 1, 'Refresh: VMs, Storage Accounts, App Service basics', 'easy'),
      (1, 2, 'Docker: Install Docker Desktop', 'easy'),
      (1, 3, 'Docker: Run ''hello-world'' container', 'easy'),
      (1, 4, 'Docker: Build first Dockerfile (simple Python app)', 'medium'),
      (2, 0, 'Docker: Multi-stage builds & best practices', 'medium'),
      (2, 1, 'Docker: Push image to Docker Hub', 'medium'),
      (2, 2, 'Azure: Set up Container Registry (ACR)', 'medium'),
      (2, 3, 'Azure: Deploy to Container Instances (ACI)', 'medium'),
      (2, 4, 'Azure: Configure networking & environment variables', 'medium'),
      (3, 0, 'Setup: Create GitHub repo + Python project skeleton', 'easy'),
      (3, 1, 'Code: Weather API integration (OpenWeatherMap or similar)', 'medium'),
      (3, 2, 'Code: Data pipeline (fetch → transform → store)', 'medium'),
      (3, 3, 'Storage: Set up Azure Blob Storage container', 'easy'),
      (3, 4, 'Code: Local testing & debugging', 'medium'),
      (4, 0, 'Docker: Containerize weather pipeline', 'medium'),
      (4, 1, 'Deploy: Push to ACR', 'easy'),
      (4, 2, 'Deploy: Run on ACI with schedule/timer', 'medium'),
      (4, 3, 'GitHub: Polish README + documentation', 'medium'),
      (4, 4, 'Blog: Write ''Deploying Weather Pipeline to Azure'' post', 'medium'),
      (5, 0, 'Azure: Request & setup Azure OpenAI Service access', 'medium'),
      (5, 1, 'Azure: Deploy GPT-4 or Claude model', 'easy'),
      (5, 2, 'FastAPI: Install & run ''Hello World'' app', 'easy'),
      (5, 3, 'FastAPI: Create first endpoint (GET, POST)', 'medium'),
      (5, 4, 'Integration: Call Azure OpenAI from FastAPI', 'medium'),
      (5, 5, 'Testing: Local testing with curl/Postman', 'medium'),
      (6, 0, 'Setup: Create new GitHub repo for Project 2', 'easy'),
      (6, 1, 'Backend: File upload endpoint (FastAPI + Python-Multipart)', 'medium'),
      (6, 2, 'Backend: Document parsing (PDF/TXT extraction)', 'hard'),
      (6, 3, 'Backend: Call Azure OpenAI for analysis', 'medium'),
      (6, 4, 'Backend: Return structured response (JSON)', 'medium'),
      (6, 5, 'Testing: End-to-end test locally', 'medium'),
      (7, 0, 'Frontend: Build simple React upload form (or Vue)', 'hard'),
      (7, 1, 'Frontend: Call backend API from React', 'medium'),
      (7, 2, 'Frontend: Display analysis results', 'medium'),
      (7, 3, 'Deploy: Push code to GitHub', 'easy'),
      (7, 4, 'Deploy: Create Dockerfile for full app', 'medium'),
      (7, 5, 'Deploy: Push to ACR + Deploy to Azure App Service', 'medium'),
      (8, 0, 'Study: Review AI-200 exam objectives & study guide', 'medium'),
      (8, 1, 'Study: Azure AI Services overview (all services)', 'hard'),
      (8, 2, 'Practice: Take first AI-200 practice exam (full)', 'hard'),
      (8, 3, 'Review: Identify weak areas from practice test', 'medium'),
      (8, 4, 'Blog: Write ''Building AI Apps with Azure OpenAI'' post', 'medium'),
      (9, 0, 'Azure ML: Set up workspace & compute instance', 'medium'),
      (9, 1, 'ML: Prepare dataset (housing, sales, or classification data)', 'medium'),
      (9, 2, 'ML: Exploratory Data Analysis (EDA) with pandas', 'medium'),
      (9, 3, 'ML: Feature engineering & preprocessing', 'hard'),
      (9, 4, 'ML: Train model (scikit-learn or AutoML)', 'medium'),
      (9, 5, 'ML: Evaluate model performance (metrics, validation)', 'medium'),
      (10, 0, 'ML: Create inference script (model predictions)', 'medium'),
      (10, 1, 'ML: Build FastAPI endpoint for predictions', 'medium'),
      (10, 2, 'ML: Create Azure ML pipeline (data → train → evaluate)', 'hard'),
      (10, 3, 'ML: Set up model registry & versioning', 'medium'),
      (10, 4, 'ML: Document pipeline architecture', 'medium'),
      (11, 0, 'Deploy: Create Azure ML endpoint for model', 'hard'),
      (11, 1, 'Deploy: Test endpoint (predictions working)', 'medium'),
      (11, 2, 'Monitor: Set up Application Insights logging', 'medium'),
      (11, 3, 'Deploy: Containerize entire ML app', 'medium'),
      (11, 4, 'GitHub: Push all code + comprehensive README', 'medium'),
      (11, 5, 'Documentation: Write ML ops workflow guide', 'medium'),
      (12, 0, 'Study: Practice exam 2 (focus on weak areas)', 'hard'),
      (12, 1, 'Study: Deep dive on Azure Cognitive Services', 'hard'),
      (12, 2, 'Study: Review real-world ML scenarios & best practices', 'hard'),
      (12, 3, 'Exam: Schedule AI-200 exam date (within 2 weeks)', 'easy'),
      (12, 4, 'Career: Polish resume with 3 projects + AI-200 target', 'medium'),
      (12, 5, 'Career: Update LinkedIn with projects & certification goal', 'easy'),
      (12, 6, 'Career: Write final blog post (3 projects overview)', 'medium'),
      (12, 7, 'Career: Start applying to Cloud/AI roles', 'medium')
    ) v(week, idx, title, difficulty)
  loop
    perform public.pt__seed_node(
      tid, 'career:w' || r.week || ':s0:i' || r.idx, 'career:w' || r.week || ':s0', 'task', r.title,
      case r.difficulty when 'easy' then 15 when 'medium' then 25 else 40 end,
      r.difficulty, r.week, null, (r.idx + 1) * 10,
      'item-' || (case when r.week <= 4 then r.week - 1 when r.week <= 8 then r.week else r.week + 1 end) || '-0-' || r.idx);
  end loop;
  for r in select * from (values
      (1, 1, 'Docker Get Started', 'https://docs.docker.com/get-started/'),
      (1, 2, 'Azure Portal Tour', 'https://learn.microsoft.com/en-us/azure/azure-portal/'),
      (2, 1, 'Docker Compose', 'https://docs.docker.com/compose/'),
      (2, 2, 'Azure Container Registry Docs', 'https://learn.microsoft.com/en-us/azure/container-registry/'),
      (2, 3, 'Container Instances Docs', 'https://learn.microsoft.com/en-us/azure/container-instances/'),
      (3, 1, 'Requests Library Docs', 'https://requests.readthedocs.io/'),
      (3, 2, 'Azure Storage SDK Python', 'https://learn.microsoft.com/en-us/python/api/overview/azure/storage'),
      (3, 3, 'GitHub Getting Started', 'https://docs.github.com/en/get-started'),
      (4, 1, 'Dev.to Writing Guide', 'https://dev.to/'),
      (4, 2, 'Markdown Guide', 'https://www.markdownguide.org/'),
      (4, 3, 'Azure Container Instances Scheduling', 'https://learn.microsoft.com/en-us/azure/container-instances/'),
      (5, 1, 'FastAPI Official Tutorial', 'https://fastapi.tiangolo.com/tutorial/'),
      (5, 2, 'Azure OpenAI Getting Started', 'https://learn.microsoft.com/en-us/azure/ai-services/openai/quickstart'),
      (5, 3, 'Azure OpenAI Python SDK', 'https://github.com/Azure/azure-sdk-for-python'),
      (6, 1, 'FastAPI File Upload', 'https://fastapi.tiangolo.com/tutorial/request-files/'),
      (6, 2, 'Python PDF Processing', 'https://pymupdf.readthedocs.io/'),
      (6, 3, 'JSON Best Practices', 'https://docs.python-guide.org/writing/style/'),
      (7, 1, 'React Official Tutorial', 'https://react.dev/learn'),
      (7, 2, 'Azure App Service Deployment', 'https://learn.microsoft.com/en-us/azure/app-service/'),
      (7, 3, 'CORS Configuration', 'https://fastapi.tiangolo.com/tutorial/cors/'),
      (8, 1, 'AI-200 Study Path', 'https://learn.microsoft.com/en-us/training/paths/prepare-for-azure-ai-engineer-certification/'),
      (8, 2, 'Azure AI Services Docs', 'https://learn.microsoft.com/en-us/azure/ai-services/'),
      (8, 3, 'Practice Exam', 'https://learn.microsoft.com/en-us/credentials/certifications/exams/ai-200/'),
      (9, 1, 'Azure ML Studio', 'https://ml.azure.com/'),
      (9, 2, 'Azure ML Documentation', 'https://learn.microsoft.com/en-us/azure/machine-learning/'),
      (9, 3, 'Scikit-learn Docs', 'https://scikit-learn.org/stable/'),
      (9, 4, 'Pandas Documentation', 'https://pandas.pydata.org/docs/'),
      (10, 1, 'Azure ML Pipelines', 'https://learn.microsoft.com/en-us/azure/machine-learning/concept-ml-pipelines'),
      (10, 2, 'MLflow Tracking', 'https://learn.microsoft.com/en-us/azure/machine-learning/how-to-use-mlflow'),
      (10, 3, 'Model Deployment Guide', 'https://learn.microsoft.com/en-us/azure/machine-learning/how-to-deploy-managed-online-endpoints'),
      (11, 1, 'Azure ML Endpoints', 'https://learn.microsoft.com/en-us/azure/machine-learning/how-to-deploy-managed-online-endpoints'),
      (11, 2, 'Application Insights', 'https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview'),
      (11, 3, 'GitHub README Best Practices', 'https://github.com/othneildrew/Best-README-Template'),
      (12, 1, 'AI-200 Exam Details', 'https://learn.microsoft.com/en-us/credentials/certifications/exams/ai-200/'),
      (12, 2, 'Pearson VUE Registration', 'https://www.pearsonvue.com/microsoft'),
      (12, 3, 'Job Boards: LinkedIn', 'https://www.linkedin.com/jobs/'),
      (12, 4, 'Tech Jobs: Stack Overflow', 'https://stackoverflow.com/jobs')
    ) v(week, ord, title, url)
  loop
    perform public.pt__seed_resource(tid, 'career:w' || r.week || ':s0', r.title, r.url, r.ord * 10);
  end loop;
end $$;

commit;

-- =====================================================================
-- COOKBOOK: common commands. Nothing below runs automatically.
-- Copy one block into the SQL Editor, change the values, and run it.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Look things up
-- ---------------------------------------------------------------------
-- Who is approved:
--    select email, display_name from users order by email;
--
-- Which trackers exist (the "slug" is the short name used below):
--    select slug, name from trackers order by name;
--
-- Who can see a tracker, and what they can do:
--    select u.email, a.role, a.can_edit
--    from tracker_access a join users u on u.id = a.user_id
--    where a.tracker_id = (select id from trackers where slug = 'godot');

-- ---------------------------------------------------------------------
-- 2. Let a new person log in
-- ---------------------------------------------------------------------
-- They must open the home page and press "Sign in with Google" once first.
-- Then approve them (name and time zone are optional):
--    select pt_admin_approve_user('friend@gmail.com', 'Friend Name', 'Asia/Kolkata');
--
-- Approved people can log in but see no trackers until you give access (step 3).

-- ---------------------------------------------------------------------
-- 3. Give or remove access to a tracker
--    Easiest: Settings (top right) > Manage trackers > Access tab.
--    Or in SQL:
-- ---------------------------------------------------------------------
-- Read & write (can tick tasks and earn XP):
--    select pt_admin_grant('godot', 'friend@gmail.com', 'member', true);
--
-- Read only (can look, cannot tick):
--    select pt_admin_grant('godot', 'friend@gmail.com', 'member', false);
--
-- Reviewer (approves a child's ticks; only for trackers that need approval):
--    select pt_admin_grant('arjun-goals', 'parent@gmail.com', 'guardian');
--
-- Remove access completely:
--    delete from tracker_access
--    where tracker_id = (select id from trackers where slug = 'godot')
--      and user_id = (select id from users where email = 'friend@gmail.com');

-- ---------------------------------------------------------------------
-- 4. Create a new tracker (you become its owner)
-- ---------------------------------------------------------------------
-- Arguments in order: slug, name, description, owner email,
--   'standard', page (null = generic page), icon, needs approval?, can untick?
-- Icons: target, gamepad, briefcase, book, star, heart, code, trophy, zap, users
--
-- Normal tracker for yourself:
--    select pt_admin_create_tracker('reading', 'Reading Habit', 'Read 12 books this year',
--      'raanginrajasthan@gmail.com', 'standard', null, 'book', false, true);
--
-- Tracker for a child, where you approve their ticks before XP is given:
--    select pt_admin_create_tracker('arjun-goals', 'Arjun''s Goals', 'Homework, reading and chores',
--      'raanginrajasthan@gmail.com', 'standard', null, 'star', true, true);
--    select pt_admin_grant('arjun-goals', 'arjun@gmail.com', 'member', true);

-- ---------------------------------------------------------------------
-- 5. Add tasks: a full sample project ("Reading Habit" from step 4)
--    You can also do this on the Manage page (Tasks tab).
--    Running a block twice adds the rows twice.
-- ---------------------------------------------------------------------
-- kind:       'phase' / 'week' / 'section' = a group that holds tasks
--             'task'   = something you tick off and earn XP for
-- xp:         points for finishing the task (groups always use 0)
-- difficulty: 'easy', 'medium', 'hard' or null
-- sort_order: position in the list, lowest first (use 10, 20, 30 to leave gaps)
--
-- Step A: add two groups:
--    insert into tasks (tracker_id, kind, title, sort_order)
--    select id, 'phase', v.title, v.ord
--    from trackers, (values ('January', 10), ('February', 20)) v(title, ord)
--    where slug = 'reading';
--
-- Step B: add tasks inside the "January" group:
--    insert into tasks (tracker_id, parent_id, kind, title, xp, difficulty, sort_order)
--    select g.tracker_id, g.id, 'task', v.title, v.xp, v.difficulty, v.ord
--    from tasks g
--    join trackers t on t.id = g.tracker_id and t.slug = 'reading'
--    cross join (values
--        ('Pick a book',            10, 'easy',   10),
--        ('Read 50 pages',          20, 'medium', 20),
--        ('Finish the book',        40, 'hard',   30),
--        ('Write a 3-line summary', 15, 'easy',   40)
--      ) v(title, xp, difficulty, ord)
--    where g.kind = 'phase' and g.title = 'January';
--
-- A single task with no group (shows at the top level):
--    insert into tasks (tracker_id, kind, title, xp, difficulty, sort_order)
--    select id, 'task', 'Join a book club', 25, 'medium', 5 from trackers where slug = 'reading';
--
-- A link shown under a group:
--    insert into task_resources (task_id, title, url, sort_order)
--    select g.id, 'Goodreads', 'https://www.goodreads.com/', 10
--    from tasks g join trackers t on t.id = g.tracker_id and t.slug = 'reading'
--    where g.kind = 'phase' and g.title = 'January';

-- ---------------------------------------------------------------------
-- 6. Change or hide tasks
-- ---------------------------------------------------------------------
-- Change XP (only affects future ticks; XP already earned stays):
--    update tasks set xp = 30
--    where title = 'Read 50 pages' and tracker_id = (select id from trackers where slug = 'reading');
--
-- Hide a task but keep its history and earned XP:
--    update tasks set archived_at = now()
--    where title = 'Join a book club' and tracker_id = (select id from trackers where slug = 'reading');
--
-- Bring it back:
--    update tasks set archived_at = null
--    where title = 'Join a book club' and tracker_id = (select id from trackers where slug = 'reading');

-- ---------------------------------------------------------------------
-- 7. Badges
-- ---------------------------------------------------------------------
-- metric: tasks_done, best_streak, current_streak, level, life_xp, today_xp,
--         tracker_tasks_done, tracker_percent, tracker_xp (tracker_* also need tracker_id)
--
-- Badge for everyone:
--    insert into badges (slug, name, description, icon, metric, threshold, sort_order)
--    values ('marathon', 'Marathon', '14-day streak', 'rocket', 'best_streak', 14, 65);
--
-- Badge for finishing one tracker:
--    insert into badges (slug, name, description, icon, metric, threshold, tracker_id, sort_order)
--    values ('bookworm', 'Bookworm', 'Finish the Reading Habit', 'book', 'tracker_percent', 100,
--            (select id from trackers where slug = 'reading'), 110);
--
-- Hide a badge without deleting it:
--    update badges set active = false where slug = 'marathon';

-- ---------------------------------------------------------------------
-- 8. One-time: bring over progress from the old Godot page (keeps level and XP)
-- ---------------------------------------------------------------------
--    select pt_admin_migrate_legacy('godot');
