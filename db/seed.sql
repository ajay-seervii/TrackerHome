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
  owner_email text := 'ajayace3@gmail.com';
begin
  perform public.pt_admin_approve_user(owner_email, null, 'Asia/Kolkata');
  update public.users set is_admin = true where lower(email) = owner_email and not is_admin;

  perform public.pt_admin_create_tracker('godot', 'Godot Game', 'Hack & slash game in Godot 4 with C#',
    owner_email, 'godot', 'godot_plan.html', 'gamepad', false, false);

  perform public.pt_admin_create_tracker('career-pivot', '12-Week Career Pivot', 'Cloud & AI/ML · AI-200 Certification',
    owner_email, 'standard', '3month_plan.html', 'briefcase', false, true);
end $$;

-- Trackers created before the role column existed: creators become owners.
update public.tracker_access a set role = 'owner'
from public.trackers t
where t.id = a.tracker_id and t.created_by = a.user_id and a.role = 'member';

-- One-time: the two custom pages became layouts of the shared tracker page.
-- Matching on the old page name means later layout/theme choices are kept.
update public.trackers set layout = 'quest', theme = 'rpg', page = null
where slug = 'godot' and page = 'godot_plan.html';
update public.trackers set layout = 'timeline', theme = 'minimal', page = null
where slug = 'career-pivot' and page = '3month_plan.html';

-- One-time: ticks that were waiting for review earned no XP under the old
-- rules. They now get it, and lose it again if the reviewer rejects them.
with upd as (
  update public.task_progress tp
  set awarded_xp = t.xp, updated_at = now()
  from public.tasks t
  where t.id = tp.task_id and tp.status = 'pending' and tp.awarded_xp is null
  returning tp.user_id, tp.tracker_id, tp.task_id, tp.awarded_xp, tp.completed_at)
insert into public.xp_events (user_id, tracker_id, task_id, amount, reason, occurred_on)
select upd.user_id, upd.tracker_id, upd.task_id, upd.awarded_xp, 'task',
       (upd.completed_at at time zone coalesce(u.timezone, 'UTC'))::date
from upd left join public.users u on u.id = upd.user_id
where upd.awarded_xp <> 0;

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

-- ---------------------------------------------------------------------
-- Sample trackers: one for each layout and several themes, owned by you.
-- They are normal trackers, so you can tick tasks and try the styles.
-- Remove them all (tasks, ticks and their XP go too):
--    delete from trackers where slug like 'sample-%';
-- Re-running this file after deleting them brings them back.
-- ---------------------------------------------------------------------
do $$
declare
  owner_email text := 'ajayace3@gmail.com';
  r record;
  tid uuid;
begin
  for r in select * from (values
      ('sample-morning-routine', 'Morning Routine', 'Small daily habits for a great start', 'checklist', 'candy', 'sun'),
      ('sample-fitness-30', '30-Day Fitness', 'Move every day, get stronger every week', 'checklist', 'neon', 'dumbbell'),
      ('sample-learn-spanish', 'Learn Spanish in 8 Weeks', 'From hola to a first real conversation', 'timeline', 'ocean', 'globe'),
      ('sample-treehouse', 'Build a Treehouse', 'A family build, chapter by chapter', 'quest', 'forest', 'tree'),
      ('sample-guitar-quest', 'Guitar Quest', 'From first chord to first song', 'quest', 'rpg', 'music'),
      ('sample-weekly-chores', 'Weekly Chores', 'Jobs that reset every Monday', 'checklist', 'minimal', 'home')
    ) v(slug, name, description, layout, theme, icon)
  loop
    perform public.pt__seed_tracker(r.slug, r.name, r.description, owner_email, r.layout, r.theme, r.icon, false);
  end loop;

  -- Groups first so tasks can find their parent.
  for r in select * from (values
      -- slug, key, parent key, kind, title, xp, difficulty, repeat, order, week, time estimate
      ('sample-morning-routine', 'wake', null::text, 'section', 'Wake up', 0, null::text, 'none', 10, null::int, null::text),
      ('sample-morning-routine', 'water', 'wake', 'task', 'Drink a glass of water', 5, 'easy', 'daily', 10, null, null),
      ('sample-morning-routine', 'bed', 'wake', 'task', 'Make your bed', 5, 'easy', 'daily', 20, null, null),
      ('sample-morning-routine', 'stretch', 'wake', 'task', 'Stretch for 5 minutes', 10, 'easy', 'daily', 30, null, null),
      ('sample-morning-routine', 'ready', null, 'section', 'Get ready', 0, null, 'none', 20, null, null),
      ('sample-morning-routine', 'teeth', 'ready', 'task', 'Brush your teeth', 5, 'easy', 'daily', 10, null, null),
      ('sample-morning-routine', 'dress', 'ready', 'task', 'Get dressed', 5, 'easy', 'daily', 20, null, null),
      ('sample-morning-routine', 'bag', 'ready', 'task', 'Pack your school bag', 10, 'medium', 'daily', 30, null, null),
      ('sample-morning-routine', 'bonus', null, 'section', 'Bonus', 0, null, 'none', 30, null, null),
      ('sample-morning-routine', 'read', 'bonus', 'task', 'Read for 10 minutes', 15, 'medium', 'daily', 10, null, null),
      ('sample-morning-routine', 'breakfast', 'bonus', 'task', 'Help make breakfast', 15, 'medium', 'weekly', 20, null, null),
      ('sample-morning-routine', 'early', 'bonus', 'task', 'Be ready 10 minutes early five days in a row', 50, 'hard', 'none', 30, null, null),

      ('sample-fitness-30', 'cardio', null, 'section', 'Cardio', 0, null, 'none', 10, null, null),
      ('sample-fitness-30', 'walk', 'cardio', 'task', '20-minute walk', 10, 'easy', 'daily', 10, null, null),
      ('sample-fitness-30', 'jacks', 'cardio', 'task', '100 jumping jacks', 10, 'easy', 'daily', 20, null, null),
      ('sample-fitness-30', 'run', 'cardio', 'task', 'Run 2 km', 25, 'medium', 'weekly', 30, null, null),
      ('sample-fitness-30', 'strength', null, 'section', 'Strength', 0, null, 'none', 20, null, null),
      ('sample-fitness-30', 'pushups', 'strength', 'task', '3 sets of push-ups', 15, 'medium', 'daily', 10, null, null),
      ('sample-fitness-30', 'squats', 'strength', 'task', '3 sets of squats', 15, 'medium', 'daily', 20, null, null),
      ('sample-fitness-30', 'recovery', null, 'section', 'Recovery', 0, null, 'none', 30, null, null),
      ('sample-fitness-30', 'stretch', 'recovery', 'task', '10-minute stretch', 10, 'easy', 'daily', 10, null, null),
      ('sample-fitness-30', 'sleep', 'recovery', 'task', '8 hours of sleep', 10, 'easy', 'daily', 20, null, null),
      ('sample-fitness-30', 'rest', 'recovery', 'task', 'Take a full rest day', 15, 'easy', 'weekly', 30, null, null),
      ('sample-fitness-30', 'boss', null, 'section', 'Challenges', 0, null, 'none', 40, null, null),
      ('sample-fitness-30', 'plank', 'boss', 'task', 'Hold a plank for 1 minute', 40, 'hard', 'none', 10, null, null),
      ('sample-fitness-30', 'fifty', 'boss', 'task', '50 push-ups in one session', 60, 'hard', 'none', 20, null, null),
      ('sample-fitness-30', 'fivek', 'boss', 'task', 'Run 5 km without stopping', 80, 'hard', 'none', 30, null, null),

      ('sample-learn-spanish', 'daily', null, 'section', 'Every day', 0, null, 'none', 5, null, null),
      ('sample-learn-spanish', 'app', 'daily', 'task', '15 minutes of app practice', 5, 'easy', 'daily', 10, null, null),
      ('sample-learn-spanish', 'words', 'daily', 'task', 'Learn 5 new words', 5, 'easy', 'daily', 20, null, null),
      ('sample-learn-spanish', 'w1', null, 'week', 'Sounds and greetings', 0, null, 'none', 10, 1, '3-4 hrs'),
      ('sample-learn-spanish', 'w2', null, 'week', 'Numbers, days and dates', 0, null, 'none', 20, 2, '3-4 hrs'),
      ('sample-learn-spanish', 'w3', null, 'week', 'Food and ordering', 0, null, 'none', 30, 3, '3-4 hrs'),
      ('sample-learn-spanish', 'w4', null, 'week', 'Family and describing people', 0, null, 'none', 40, 4, '3-4 hrs'),
      ('sample-learn-spanish', 'm1', null, 'divider', 'Milestone: you can introduce yourself', 0, null, 'none', 45, 4, null),
      ('sample-learn-spanish', 'w5', null, 'week', 'Present tense verbs', 0, null, 'none', 50, 5, '4-5 hrs'),
      ('sample-learn-spanish', 'w6', null, 'week', 'Getting around town', 0, null, 'none', 60, 6, '4-5 hrs'),
      ('sample-learn-spanish', 'w7', null, 'week', 'Past tense basics', 0, null, 'none', 70, 7, '4-5 hrs'),
      ('sample-learn-spanish', 'w8', null, 'week', 'Your first real conversation', 0, null, 'none', 80, 8, '4-5 hrs'),
      ('sample-learn-spanish', 'm2', null, 'divider', 'Milestone: first conversation done', 0, null, 'none', 85, 8, null),
      ('sample-learn-spanish', 'w1a', 'w1', 'task', 'Learn the alphabet and vowel sounds', 15, 'easy', 'none', 10, null, null),
      ('sample-learn-spanish', 'w1b', 'w1', 'task', 'Practise 10 greetings out loud', 15, 'easy', 'none', 20, null, null),
      ('sample-learn-spanish', 'w1c', 'w1', 'task', 'Introduce yourself in 3 sentences', 25, 'medium', 'none', 30, null, null),
      ('sample-learn-spanish', 'w2a', 'w2', 'task', 'Count to 100', 15, 'easy', 'none', 10, null, null),
      ('sample-learn-spanish', 'w2b', 'w2', 'task', 'Say the days of the week and the months', 15, 'easy', 'none', 20, null, null),
      ('sample-learn-spanish', 'w2c', 'w2', 'task', 'Say today''s date in Spanish', 25, 'medium', 'none', 30, null, null),
      ('sample-learn-spanish', 'w3a', 'w3', 'task', 'Learn 30 food words', 25, 'medium', 'none', 10, null, null),
      ('sample-learn-spanish', 'w3b', 'w3', 'task', 'Role-play ordering at a cafe', 25, 'medium', 'none', 20, null, null),
      ('sample-learn-spanish', 'w3c', 'w3', 'task', 'Write a shopping list in Spanish', 15, 'easy', 'none', 30, null, null),
      ('sample-learn-spanish', 'w4a', 'w4', 'task', 'Describe your family in 5 sentences', 25, 'medium', 'none', 10, null, null),
      ('sample-learn-spanish', 'w4b', 'w4', 'task', 'Learn 20 adjectives', 25, 'medium', 'none', 20, null, null),
      ('sample-learn-spanish', 'w4c', 'w4', 'task', 'Record a 1-minute introduction', 40, 'hard', 'none', 30, null, null),
      ('sample-learn-spanish', 'w5a', 'w5', 'task', 'Conjugate 10 regular -ar verbs', 25, 'medium', 'none', 10, null, null),
      ('sample-learn-spanish', 'w5b', 'w5', 'task', 'Learn when to use ser and estar', 40, 'hard', 'none', 20, null, null),
      ('sample-learn-spanish', 'w5c', 'w5', 'task', 'Write 10 sentences about your day', 25, 'medium', 'none', 30, null, null),
      ('sample-learn-spanish', 'w6a', 'w6', 'task', 'Learn left, right, straight on and near', 15, 'easy', 'none', 10, null, null),
      ('sample-learn-spanish', 'w6b', 'w6', 'task', 'Ask for directions in a role-play', 25, 'medium', 'none', 20, null, null),
      ('sample-learn-spanish', 'w6c', 'w6', 'task', 'Plan a trip around a town map in Spanish', 25, 'medium', 'none', 30, null, null),
      ('sample-learn-spanish', 'w7a', 'w7', 'task', 'Learn the past tense of 10 verbs', 40, 'hard', 'none', 10, null, null),
      ('sample-learn-spanish', 'w7b', 'w7', 'task', 'Tell someone what you did yesterday', 25, 'medium', 'none', 20, null, null),
      ('sample-learn-spanish', 'w7c', 'w7', 'task', 'Watch a short video in Spanish', 15, 'easy', 'none', 30, null, null),
      ('sample-learn-spanish', 'w8a', 'w8', 'task', 'Review all your flashcards', 25, 'medium', 'none', 10, null, null),
      ('sample-learn-spanish', 'w8b', 'w8', 'task', 'Have a 5-minute conversation', 40, 'hard', 'none', 20, null, null),
      ('sample-learn-spanish', 'w8c', 'w8', 'task', 'Write a short postcard', 25, 'medium', 'none', 30, null, null),

      ('sample-treehouse', 'plan', null, 'phase', 'Draw the plans', 0, null, 'none', 10, null, null),
      ('sample-treehouse', 'gather', null, 'phase', 'Gather supplies', 0, null, 'none', 20, null, null),
      ('sample-treehouse', 'build', null, 'phase', 'Build the frame', 0, null, 'none', 30, null, null),
      ('sample-treehouse', 'finish', null, 'phase', 'Finishing touches', 0, null, 'none', 40, null, null),
      ('sample-treehouse', 'tree', 'plan', 'task', 'Pick the tree', 15, 'easy', 'none', 10, null, null),
      ('sample-treehouse', 'measure', 'plan', 'task', 'Measure the branches', 20, 'easy', 'none', 20, null, null),
      ('sample-treehouse', 'sketch', 'plan', 'task', 'Sketch the design', 30, 'medium', 'none', 30, null, null),
      ('sample-treehouse', 'safety', 'plan', 'task', 'Ask a grown-up to check it is safe', 25, 'easy', 'none', 40, null, null),
      ('sample-treehouse', 'list', 'gather', 'task', 'List the wood and tools needed', 20, 'easy', 'none', 10, null, null),
      ('sample-treehouse', 'shop', 'gather', 'task', 'Visit the hardware store', 25, 'medium', 'none', 20, null, null),
      ('sample-treehouse', 'gear', 'gather', 'task', 'Collect gloves and goggles', 15, 'easy', 'none', 30, null, null),
      ('sample-treehouse', 'platform', 'build', 'task', 'Build the platform', 50, 'hard', 'none', 10, null, null),
      ('sample-treehouse', 'rails', 'build', 'task', 'Add the railings', 40, 'hard', 'none', 20, null, null),
      ('sample-treehouse', 'ladder', 'build', 'task', 'Fix the ladder', 40, 'hard', 'none', 30, null, null),
      ('sample-treehouse', 'paint', 'finish', 'task', 'Paint it', 30, 'medium', 'none', 10, null, null),
      ('sample-treehouse', 'sign', 'finish', 'task', 'Make a name sign', 20, 'easy', 'none', 20, null, null),
      ('sample-treehouse', 'picnic', 'finish', 'task', 'Have a treehouse picnic', 50, 'easy', 'none', 30, null, null),

      ('sample-guitar-quest', 'act1', null, 'phase', 'Act I: The Apprentice', 0, null, 'none', 10, null, null),
      ('sample-guitar-quest', 'act2', null, 'phase', 'Act II: The Journeyman', 0, null, 'none', 20, null, null),
      ('sample-guitar-quest', 'act3', null, 'phase', 'Act III: The Bard', 0, null, 'none', 30, null, null),
      ('sample-guitar-quest', 'practice', 'act1', 'task', 'Practise for 15 minutes', 10, 'easy', 'daily', 5, null, null),
      ('sample-guitar-quest', 'parts', 'act1', 'task', 'Learn the parts of the guitar', 10, 'easy', 'none', 10, null, null),
      ('sample-guitar-quest', 'tune', 'act1', 'task', 'Tune the guitar', 15, 'easy', 'none', 20, null, null),
      ('sample-guitar-quest', 'minor', 'act1', 'task', 'Play E minor and A minor', 25, 'medium', 'none', 30, null, null),
      ('sample-guitar-quest', 'chords', 'act2', 'task', 'Learn C, G and D chords', 40, 'hard', 'none', 10, null, null),
      ('sample-guitar-quest', 'switch', 'act2', 'task', 'Switch chords in time with a metronome', 40, 'hard', 'none', 20, null, null),
      ('sample-guitar-quest', 'strum', 'act2', 'task', 'Learn a strumming pattern', 25, 'medium', 'none', 30, null, null),
      ('sample-guitar-quest', 'song', 'act3', 'task', 'Learn a full song', 60, 'hard', 'none', 10, null, null),
      ('sample-guitar-quest', 'perform', 'act3', 'task', 'Play it for someone', 50, 'hard', 'none', 20, null, null),
      ('sample-guitar-quest', 'record', 'act3', 'task', 'Record yourself playing', 30, 'medium', 'none', 30, null, null),

      ('sample-weekly-chores', 'kitchen', null, 'section', 'Kitchen', 0, null, 'none', 10, null, null),
      ('sample-weekly-chores', 'dishes', 'kitchen', 'task', 'Empty the dishwasher', 10, 'easy', 'weekly', 10, null, null),
      ('sample-weekly-chores', 'counters', 'kitchen', 'task', 'Wipe the counters', 10, 'easy', 'weekly', 20, null, null),
      ('sample-weekly-chores', 'recycling', 'kitchen', 'task', 'Take out the recycling', 10, 'easy', 'weekly', 30, null, null),
      ('sample-weekly-chores', 'bedroom', null, 'section', 'Bedroom', 0, null, 'none', 20, null, null),
      ('sample-weekly-chores', 'tidy', 'bedroom', 'task', 'Tidy your room', 15, 'medium', 'weekly', 10, null, null),
      ('sample-weekly-chores', 'sheets', 'bedroom', 'task', 'Change the bed sheets', 15, 'medium', 'weekly', 20, null, null),
      ('sample-weekly-chores', 'laundry', 'bedroom', 'task', 'Put your laundry away', 10, 'easy', 'weekly', 30, null, null),
      ('sample-weekly-chores', 'outside', null, 'section', 'Outside', 0, null, 'none', 30, null, null),
      ('sample-weekly-chores', 'plants', 'outside', 'task', 'Water the plants', 10, 'easy', 'weekly', 10, null, null),
      ('sample-weekly-chores', 'sweep', 'outside', 'task', 'Sweep the porch', 15, 'medium', 'weekly', 20, null, null),
      ('sample-weekly-chores', 'car', 'outside', 'task', 'Help wash the car', 25, 'medium', 'weekly', 30, null, null)
    ) v(slug, key, parent, kind, title, xp, difficulty, rep, ord, week, est)
    order by (v.kind = 'task')
  loop
    tid := (select id from public.trackers where slug = r.slug);
    perform public.pt__seed_node(tid, r.slug || ':' || r.key,
      case when r.parent is null then null else r.slug || ':' || r.parent end,
      r.kind, r.title, r.xp, r.difficulty, r.week, r.est, r.ord, null, r.rep);
  end loop;

  for r in select * from (values
      ('sample-learn-spanish', 'w1', 'Duolingo', 'https://www.duolingo.com/', 10),
      ('sample-learn-spanish', 'w1', 'SpanishDict', 'https://www.spanishdict.com/', 20),
      ('sample-learn-spanish', 'w8', 'Tandem language exchange', 'https://www.tandem.net/', 10),
      ('sample-guitar-quest', 'act1', 'JustinGuitar beginner lessons', 'https://www.justinguitar.com/', 10)
    ) v(slug, key, title, url, ord)
  loop
    tid := (select id from public.trackers where slug = r.slug);
    perform public.pt__seed_resource(tid, r.slug || ':' || r.key, r.title, r.url, r.ord);
  end loop;
end $$;

commit;

-- =====================================================================
-- COOKBOOK: common commands. Nothing below runs automatically.
-- Copy one block into the SQL Editor, change the values, and run it.
-- Step-by-step walkthroughs: docs/SQL_GUIDE.md (SQL) and
-- docs/PORTAL_GUIDE.md (the same things from the website).
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
--    Easiest: Settings > Manage > People tab > Add a person.
-- ---------------------------------------------------------------------
-- Before they have signed in (they are approved on their first Google sign-in):
--    insert into invites (email, display_name, timezone)
--    values ('friend@gmail.com', 'Friend Name', 'Asia/Kolkata');
--
-- After they have pressed "Sign in with Google" once:
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
--    Easiest: Manage page > New tracker (can also copy an existing one).
-- ---------------------------------------------------------------------
-- Arguments in order: slug, name, description, owner email, layout, theme, icon, needs approval?
-- Layouts: checklist, timeline, quest
-- Themes:  minimal, rpg, neon, ocean, forest, candy
-- Icons:   target, gamepad, briefcase, book, star, heart, code, trophy, zap, users,
--          sun, music, dumbbell, globe, tree, home
--
-- Normal tracker for yourself:
--    select pt__seed_tracker('reading', 'Reading Habit', 'Read 12 books this year',
--      'ajayace3@gmail.com', 'checklist', 'minimal', 'book', false);
--
-- Tracker for a child. XP is given as soon as they tick a task and shows as
-- "pending review"; if you reject it, the XP is taken back:
--    select pt__seed_tracker('arjun-goals', 'Arjun''s Goals', 'Homework, reading and chores',
--      'ajayace3@gmail.com', 'quest', 'candy', 'star', true);
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
-- repeat:     'none' (tick once), 'daily' or 'weekly' (resets every day / every Monday)
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
-- A task that resets every day:
--    insert into tasks (tracker_id, kind, title, xp, difficulty, repeat, sort_order)
--    select id, 'task', 'Read for 20 minutes', 10, 'easy', 'daily', 1 from trackers where slug = 'reading';
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

-- ---------------------------------------------------------------------
-- 9. Change how a tracker looks (also on the Manage page > Settings)
-- ---------------------------------------------------------------------
--    update trackers set layout = 'quest', theme = 'forest' where slug = 'reading';

-- ---------------------------------------------------------------------
-- 10. Sample trackers
-- ---------------------------------------------------------------------
-- Delete all samples (their ticks and XP go too):
--    delete from trackers where slug like 'sample-%';
--
-- Keep one sample by renaming its slug first, e.g.:
--    update trackers set slug = 'chores' where slug = 'sample-weekly-chores';

-- ---------------------------------------------------------------------
-- 11. People
-- ---------------------------------------------------------------------
-- Make someone else a site admin (can add people from the portal):
--    update users set is_admin = true where email = 'partner@gmail.com';
--
-- Remove a person (keeps their history; approve again to restore):
--    delete from tracker_access where user_id = (select id from users where email = 'friend@gmail.com');
--    delete from users where email = 'friend@gmail.com';
