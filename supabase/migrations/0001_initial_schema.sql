-- Internal Learning Portal: foundational schema. Apply using Supabase migrations.
create extension if not exists pgcrypto;

create type public.user_role as enum ('admin','teacher','student');
create type public.question_kind as enum ('mcq_single','mcq_multi','true_false','short_answer');
create type public.attempt_status as enum ('in_progress','submitted','graded');
create type public.complaint_category as enum ('academic','technical','facility','conduct','other');
create type public.complaint_status as enum ('open','in_review','resolved','rejected');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 1 and 120),
  email text not null unique,
  role public.user_role not null,
  roll_number text unique,
  is_active boolean not null default true,
  must_change_password boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.courses (
  id uuid primary key default gen_random_uuid(), code text not null unique,
  title text not null, description text not null default '', teacher_id uuid not null references public.profiles(id),
  is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.enrollments (
  id uuid primary key default gen_random_uuid(), course_id uuid not null references public.courses(id) on delete cascade,
  student_id uuid not null references public.profiles(id), enrolled_at timestamptz not null default now(), unique(course_id,student_id)
);
create table public.resources (
  id uuid primary key default gen_random_uuid(), course_id uuid not null references public.courses(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id), title text not null, description text not null default '',
  file_path text not null unique, file_name text not null, file_size bigint not null check(file_size between 1 and 20971520),
  mime_type text not null, created_at timestamptz not null default now()
);
create table public.assignments (
  id uuid primary key default gen_random_uuid(), course_id uuid not null references public.courses(id) on delete cascade,
  title text not null, instructions text not null default '', due_at timestamptz, max_marks numeric(8,2) not null check(max_marks > 0),
  allow_late boolean not null default false, attachment_path text, created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.submissions (
  id uuid primary key default gen_random_uuid(), assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.profiles(id), file_path text, text_answer text,
  submitted_at timestamptz not null default now(), is_late boolean not null default false,
  marks_obtained numeric(8,2), feedback text, graded_by uuid references public.profiles(id), graded_at timestamptz,
  unique(assignment_id,student_id), check(file_path is not null or nullif(trim(text_answer),'') is not null)
);
create table public.quizzes (
  id uuid primary key default gen_random_uuid(), course_id uuid not null references public.courses(id) on delete cascade,
  title text not null, instructions text not null default '', start_at timestamptz, end_at timestamptz,
  duration_minutes integer not null check(duration_minutes between 1 and 600), max_marks numeric(8,2) not null check(max_marks > 0),
  shuffle_questions boolean not null default false, is_published boolean not null default false,
  created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(start_at is null or end_at is null or end_at > start_at)
);
create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(), quiz_id uuid not null references public.quizzes(id) on delete cascade,
  type public.question_kind not null, question_text text not null, options jsonb not null default '[]',
  marks numeric(8,2) not null check(marks > 0), position integer not null default 0
);
-- Answer keys are kept in a separate table so learners can never query them directly.
create table public.quiz_answer_keys (
  question_id uuid primary key references public.quiz_questions(id) on delete cascade,
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  correct_answer jsonb not null
);
create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(), quiz_id uuid not null references public.quizzes(id) on delete cascade,
  student_id uuid not null references public.profiles(id), started_at timestamptz not null default now(), submitted_at timestamptz,
  answers jsonb not null default '{}', score numeric(8,2), status public.attempt_status not null default 'in_progress',
  unique(quiz_id,student_id)
);
create table public.announcements (
  id uuid primary key default gen_random_uuid(), course_id uuid references public.courses(id) on delete cascade,
  author_id uuid not null references public.profiles(id), title text not null, body text not null,
  is_pinned boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.announcement_reads (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade, read_at timestamptz not null default now(),
  primary key(announcement_id,user_id)
);
create table public.chat_messages (
  id uuid primary key default gen_random_uuid(), course_id uuid not null references public.courses(id) on delete cascade,
  sender_id uuid not null references public.profiles(id), body text not null check(char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(), deleted_at timestamptz
);
create table public.complaints (
  id uuid primary key default gen_random_uuid(), submitted_by uuid not null references public.profiles(id),
  category public.complaint_category not null, subject text not null, description text not null, attachment_path text,
  status public.complaint_status not null default 'open', admin_response text, resolved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.audit_log (
  id bigint generated always as identity primary key, actor_id uuid references public.profiles(id),
  action text not null, entity_type text not null, entity_id uuid not null, old_value jsonb, new_value jsonb,
  created_at timestamptz not null default now()
);

create index enrollments_student_idx on public.enrollments(student_id,course_id);
create index courses_teacher_idx on public.courses(teacher_id);
create index resources_course_created_idx on public.resources(course_id,created_at desc);
create index resources_uploaded_by_idx on public.resources(uploaded_by);
create index assignments_course_due_idx on public.assignments(course_id,due_at);
create index assignments_created_by_idx on public.assignments(created_by);
create index submissions_student_idx on public.submissions(student_id,submitted_at desc);
create index submissions_graded_by_idx on public.submissions(graded_by);
create index quiz_questions_order_idx on public.quiz_questions(quiz_id,position);
create index quiz_answer_keys_quiz_idx on public.quiz_answer_keys(quiz_id);
create index attempts_student_idx on public.quiz_attempts(student_id,quiz_id);
create index quizzes_created_by_idx on public.quizzes(created_by);
create index announcements_course_created_idx on public.announcements(course_id,is_pinned desc,created_at desc);
create index announcements_author_idx on public.announcements(author_id);
create index announcement_reads_user_idx on public.announcement_reads(user_id);
create index chat_course_created_idx on public.chat_messages(course_id,created_at desc);
create index chat_sender_idx on public.chat_messages(sender_id);
create index complaints_submitter_status_idx on public.complaints(submitted_by,status,created_at desc);
create index complaints_resolved_by_idx on public.complaints(resolved_by);
create index audit_entity_idx on public.audit_log(entity_type,entity_id,created_at desc);
create index audit_actor_idx on public.audit_log(actor_id,created_at desc);

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger courses_touch before update on public.courses for each row execute function public.touch_updated_at();
create trigger assignments_touch before update on public.assignments for each row execute function public.touch_updated_at();
create trigger quizzes_touch before update on public.quizzes for each row execute function public.touch_updated_at();
create trigger announcements_touch before update on public.announcements for each row execute function public.touch_updated_at();
create trigger complaints_touch before update on public.complaints for each row execute function public.touch_updated_at();

create or replace function public.current_role() returns public.user_role
language sql stable security definer set search_path = public as $$ select role from public.profiles where id=auth.uid() and is_active $$;
create or replace function public.is_teacher_of(target_course uuid) returns boolean
language sql stable security definer set search_path = public as $$ select exists(select 1 from public.courses where id=target_course and teacher_id=auth.uid() and is_active) $$;
create or replace function public.is_enrolled_in(target_course uuid) returns boolean
language sql stable security definer set search_path = public as $$ select exists(select 1 from public.enrollments where course_id=target_course and student_id=auth.uid()) $$;
create or replace function public.can_access_course(target_course uuid) returns boolean
language sql stable security definer set search_path=public as $$ select public.current_role()='admin' or public.is_teacher_of(target_course) or public.is_enrolled_in(target_course) $$;
create or replace function public.prepare_submission() returns trigger language plpgsql security definer set search_path=public as $$
declare deadline timestamptz; late_allowed boolean;
begin
  if tg_op='UPDATE' and new.file_path is not distinct from old.file_path and new.text_answer is not distinct from old.text_answer then return new; end if;
  select due_at,allow_late into deadline,late_allowed from public.assignments where id=new.assignment_id;
  if deadline is not null and now()>deadline and not late_allowed then raise exception 'Submission deadline has passed'; end if;
  new.submitted_at=now(); new.is_late=(deadline is not null and now()>deadline);
  if tg_op='INSERT' then new.marks_obtained=null; new.feedback=null; new.graded_by=null; new.graded_at=null; end if;
  return new;
end $$;
create trigger submissions_prepare before insert or update on public.submissions for each row execute function public.prepare_submission();
create or replace function public.prepare_quiz_attempt() returns trigger language plpgsql security definer set search_path=public as $$
begin
  new.started_at=now(); new.submitted_at=null; new.answers='{}'::jsonb; new.score=null; new.status='in_progress';
  return new;
end $$;
create trigger quiz_attempts_prepare before insert on public.quiz_attempts for each row execute function public.prepare_quiz_attempt();

create or replace function public.grade_submission(p_submission_id uuid,p_marks numeric,p_feedback text default '') returns public.submissions
language plpgsql security definer set search_path=public as $$
declare s public.submissions; maximum numeric;
begin
  select a.max_marks into maximum from public.submissions x join public.assignments a on a.id=x.assignment_id where x.id=p_submission_id;
  if not found then raise exception 'Submission not found'; end if;
  if public.current_role() not in ('teacher','admin') or not exists(select 1 from public.submissions x join public.assignments a on a.id=x.assignment_id where x.id=p_submission_id and (public.current_role()='admin' or public.is_teacher_of(a.course_id))) then raise exception 'Forbidden'; end if;
  if p_marks<0 or p_marks>maximum then raise exception 'Marks are outside the allowed range'; end if;
  update public.submissions set marks_obtained=p_marks,feedback=p_feedback,graded_by=auth.uid(),graded_at=now() where id=p_submission_id returning * into s;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,new_value) values(auth.uid(),'grade_submission','submission',p_submission_id,jsonb_build_object('marks_obtained',p_marks,'feedback',p_feedback));
  return s;
end $$;

create or replace function public.save_submission(p_assignment_id uuid,p_file_path text,p_text_answer text) returns public.submissions
language plpgsql security definer set search_path=public as $$
declare s public.submissions; deadline timestamptz; late_allowed boolean; target_course uuid;
begin
  if public.current_role()<>'student' then raise exception 'Forbidden'; end if;
  if p_file_path is null and nullif(trim(p_text_answer),'') is null then raise exception 'Submission cannot be empty'; end if;
  select due_at,allow_late,course_id into deadline,late_allowed,target_course from public.assignments where id=p_assignment_id;
  if not found then raise exception 'Assignment not found'; end if;
  if not public.is_enrolled_in(target_course) then raise exception 'Forbidden'; end if;
  if deadline is not null and now()>deadline and not late_allowed then raise exception 'Submission deadline has passed'; end if;
  if p_file_path is not null and split_part(p_file_path,'/',1)<>p_assignment_id::text then raise exception 'Invalid submission file'; end if;
  if p_file_path is not null and split_part(p_file_path,'/',2)<>auth.uid()::text then raise exception 'Invalid submission file'; end if;
  insert into public.submissions(assignment_id,student_id,file_path,text_answer)
    values(p_assignment_id,auth.uid(),p_file_path,p_text_answer)
    on conflict(assignment_id,student_id) do update set file_path=excluded.file_path,text_answer=excluded.text_answer
    where public.submissions.graded_at is null returning * into s;
  if not found then raise exception 'This work has already been graded'; end if;
  return s;
end $$;

create or replace function public.submit_quiz_attempt(p_quiz_id uuid,p_answers jsonb) returns public.quiz_attempts
language plpgsql security definer set search_path=public as $$
declare a public.quiz_attempts; q public.quizzes; deadline timestamptz; calculated_score numeric; needs_manual boolean;
begin
  if public.current_role()<>'student' then raise exception 'Forbidden'; end if;
  select * into q from public.quizzes where id=p_quiz_id;
  select * into a from public.quiz_attempts where quiz_id=p_quiz_id and student_id=auth.uid() for update;
  if not found or a.status<>'in_progress' then raise exception 'Attempt unavailable'; end if;
  deadline=least(a.started_at+make_interval(mins=>q.duration_minutes),coalesce(q.end_at,'infinity'::timestamptz));
  if now()>deadline then raise exception 'Quiz deadline has passed'; end if;
  select coalesce(sum(case when qq.type<>'short_answer' and p_answers -> (qq.id::text)=ak.correct_answer then qq.marks else 0 end),0),coalesce(bool_or(qq.type='short_answer'),false)
    into calculated_score,needs_manual from public.quiz_questions qq join public.quiz_answer_keys ak on ak.question_id=qq.id where qq.quiz_id=p_quiz_id;
  update public.quiz_attempts set answers=p_answers,submitted_at=now(),score=calculated_score,status=case when needs_manual then 'submitted'::public.attempt_status else 'graded'::public.attempt_status end where id=a.id returning * into a;
  return a;
end $$;

create or replace function public.grade_quiz_attempt(p_attempt_id uuid,p_score numeric) returns public.quiz_attempts
language plpgsql security definer set search_path=public as $$
declare a public.quiz_attempts; maximum numeric;
begin
  select qa.* into a from public.quiz_attempts qa join public.quizzes q on q.id=qa.quiz_id where qa.id=p_attempt_id;
  select q.max_marks into maximum from public.quiz_attempts qa join public.quizzes q on q.id=qa.quiz_id where qa.id=p_attempt_id;
  if not found then raise exception 'Attempt not found'; end if;
  if public.current_role() not in ('teacher','admin') or not exists(select 1 from public.quiz_attempts qa join public.quizzes q on q.id=qa.quiz_id where qa.id=p_attempt_id and (public.current_role()='admin' or public.is_teacher_of(q.course_id))) then raise exception 'Forbidden'; end if;
  if p_score<0 or p_score>maximum then raise exception 'Marks are outside the allowed range'; end if;
  update public.quiz_attempts set score=p_score,status='graded' where id=p_attempt_id returning * into a;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,new_value) values(auth.uid(),'grade_quiz','quiz_attempt',p_attempt_id,jsonb_build_object('score',p_score));
  return a;
end $$;

alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.enrollments enable row level security;
alter table public.resources enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_answer_keys enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.announcements enable row level security;
alter table public.announcement_reads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.complaints enable row level security;
alter table public.audit_log enable row level security;

create policy "profiles self or admin read" on public.profiles for select using(id=auth.uid() or public.current_role()='admin' or (public.current_role()='teacher' and exists(select 1 from public.courses c join public.enrollments e on e.course_id=c.id where c.teacher_id=auth.uid() and e.student_id=profiles.id)));
create policy "profiles self update name" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());
grant update(full_name) on public.profiles to authenticated;
create policy "admin manages profiles" on public.profiles for all using(public.current_role()='admin') with check(public.current_role()='admin');
create policy "courses visible to participants" on public.courses for select using(is_active and public.can_access_course(id) or public.current_role()='admin');
create policy "admin manages courses" on public.courses for all using(public.current_role()='admin') with check(public.current_role()='admin');
create policy "enrollments visible to participants" on public.enrollments for select using(student_id=auth.uid() or public.is_teacher_of(course_id) or public.current_role()='admin');
create policy "admin manages enrollments" on public.enrollments for all using(public.current_role()='admin') with check(public.current_role()='admin');
create policy "resources read by course members" on public.resources for select using(public.can_access_course(course_id));
create policy "teachers manage own resources" on public.resources for all using(public.is_teacher_of(course_id) or public.current_role()='admin') with check(public.is_teacher_of(course_id) or public.current_role()='admin');
create policy "assignments visible to course members" on public.assignments for select using(public.can_access_course(course_id));
create policy "teachers manage assignments" on public.assignments for all using(public.is_teacher_of(course_id) or public.current_role()='admin') with check(public.is_teacher_of(course_id) or public.current_role()='admin');
create policy "submissions visible to owner or course teacher" on public.submissions for select using(student_id=auth.uid() or exists(select 1 from public.assignments a where a.id=assignment_id and (public.is_teacher_of(a.course_id) or public.current_role()='admin')));
create policy "students submit own work" on public.submissions for insert with check(student_id=auth.uid() and public.current_role()='student' and marks_obtained is null and feedback is null and graded_by is null and graded_at is null);
create policy "students update own ungraded work" on public.submissions for update using(student_id=auth.uid() and graded_at is null) with check(student_id=auth.uid() and graded_at is null);
create policy "teachers read submissions to grade" on public.submissions for update using(exists(select 1 from public.assignments a where a.id=assignment_id and (public.is_teacher_of(a.course_id) or public.current_role()='admin')));
create policy "quizzes visible to participants" on public.quizzes for select using((public.current_role() in ('teacher','admin') and public.can_access_course(course_id)) or (public.current_role()='student' and is_published and public.is_enrolled_in(course_id)));
create policy "teachers manage quizzes" on public.quizzes for all using(public.is_teacher_of(course_id) or public.current_role()='admin') with check(public.is_teacher_of(course_id) or public.current_role()='admin');
create policy "questions visible to active participants" on public.quiz_questions for select using(exists(select 1 from public.quizzes q where q.id=quiz_id and ((public.current_role() in ('teacher','admin') and public.can_access_course(q.course_id)) or (public.current_role()='student' and q.is_published and public.is_enrolled_in(q.course_id) and (q.start_at is null or now()>=q.start_at) and (q.end_at is null or now()<=q.end_at) and exists(select 1 from public.quiz_attempts qa where qa.quiz_id=q.id and qa.student_id=auth.uid() and qa.status='in_progress')))));
create policy "teachers manage questions" on public.quiz_questions for all using(exists(select 1 from public.quizzes q where q.id=quiz_id and (public.is_teacher_of(q.course_id) or public.current_role()='admin')));
create policy "teachers manage quiz answer keys" on public.quiz_answer_keys for all using(exists(select 1 from public.quizzes q where q.id=quiz_id and (public.is_teacher_of(q.course_id) or public.current_role()='admin'))) with check(exists(select 1 from public.quizzes q where q.id=quiz_id and (public.is_teacher_of(q.course_id) or public.current_role()='admin')));
create policy "attempt owner or course teacher" on public.quiz_attempts for select using(student_id=auth.uid() or exists(select 1 from public.quizzes q where q.id=quiz_id and (public.is_teacher_of(q.course_id) or public.current_role()='admin')));
create policy "students start own attempts" on public.quiz_attempts for insert with check(student_id=auth.uid() and public.current_role()='student' and exists(select 1 from public.quizzes q where q.id=quiz_id and q.is_published and public.is_enrolled_in(q.course_id) and (q.start_at is null or now()>=q.start_at) and (q.end_at is null or now()<=q.end_at)));
create policy "students save own attempts" on public.quiz_attempts for update using(student_id=auth.uid() and public.current_role()='student' and status='in_progress' and now()<=started_at+(select make_interval(mins=>q.duration_minutes) from public.quizzes q where q.id=quiz_id) and exists(select 1 from public.quizzes q where q.id=quiz_id and (q.end_at is null or now()<=q.end_at))) with check(student_id=auth.uid() and public.current_role()='student' and status='in_progress');
create policy "announcements visible to audience" on public.announcements for select using(course_id is null and public.current_role() is not null or course_id is not null and public.can_access_course(course_id));
create policy "author or admin manages announcements" on public.announcements for all using(public.current_role()='admin' or author_id=auth.uid() and (public.current_role()='admin' or course_id is not null and public.is_teacher_of(course_id))) with check(public.current_role()='admin' or author_id=auth.uid() and (public.current_role()='admin' or course_id is not null and public.is_teacher_of(course_id)));
create policy "users manage own announcement reads" on public.announcement_reads for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "chat readable by course members" on public.chat_messages for select using(public.can_access_course(course_id));
create policy "members send chat" on public.chat_messages for insert with check(sender_id=auth.uid() and public.can_access_course(course_id));
create policy "author or staff soft delete chat" on public.chat_messages for update using(sender_id=auth.uid() or public.is_teacher_of(course_id) or public.current_role()='admin') with check(deleted_at is not null and (sender_id=auth.uid() or public.is_teacher_of(course_id) or public.current_role()='admin'));
create policy "submitter or admin reads complaint" on public.complaints for select using(submitted_by=auth.uid() or public.current_role()='admin');
create policy "users submit complaints" on public.complaints for insert with check(submitted_by=auth.uid() and status='open' and admin_response is null and resolved_by is null);
create policy "admins resolve complaints" on public.complaints for update using(public.current_role()='admin') with check(public.current_role()='admin');
create policy "admins read audit" on public.audit_log for select using(public.current_role()='admin');

-- Column grants prevent clients from promoting themselves, changing grades, or bypassing quiz scoring.
revoke update on public.profiles from authenticated;
grant update(full_name) on public.profiles to authenticated;
revoke update,insert on public.submissions from authenticated;
revoke update on public.quiz_attempts from authenticated;
grant update(answers) on public.quiz_attempts to authenticated;
grant execute on function public.submit_quiz_attempt(uuid,jsonb) to authenticated;
grant execute on function public.save_submission(uuid,text,text) to authenticated;
grant execute on function public.grade_submission(uuid,numeric,text) to authenticated;
grant execute on function public.grade_quiz_attempt(uuid,numeric) to authenticated;
revoke all on function public.submit_quiz_attempt(uuid,jsonb) from public,anon;
revoke all on function public.save_submission(uuid,text,text) from public,anon;
revoke all on function public.grade_submission(uuid,numeric,text) from public,anon;
revoke all on function public.grade_quiz_attempt(uuid,numeric) from public,anon;
revoke update on public.chat_messages from authenticated;
grant update(deleted_at) on public.chat_messages to authenticated;
grant select on public.quiz_answer_keys to authenticated;

-- Private buckets for course materials and learner submissions.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
  ('resources','resources',false,20971520,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.presentationml.presentation','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/png','image/jpeg','video/mp4','application/zip']),
  ('submissions','submissions',false,20971520,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.presentationml.presentation','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/png','image/jpeg','video/mp4','application/zip'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

-- The API creates 60-second signed links after checking membership. Buckets stay private.
drop policy if exists "resource members may read objects" on storage.objects;
create policy "resource members may read objects" on storage.objects for select to authenticated
  using(bucket_id='resources' and public.can_access_course((storage.foldername(name))[1]::uuid));
create policy "course teachers may upload resource objects" on storage.objects for insert to authenticated
  with check(bucket_id='resources' and (public.is_teacher_of((storage.foldername(name))[1]::uuid) or public.current_role()='admin'));
create policy "course teachers may delete resource objects" on storage.objects for delete to authenticated
  using(bucket_id='resources' and (public.is_teacher_of((storage.foldername(name))[1]::uuid) or public.current_role()='admin'));
create policy "submission owners and teachers may read files" on storage.objects for select to authenticated
  using(bucket_id='submissions' and (
    (storage.foldername(name))[2]=auth.uid()::text or
    public.current_role()='admin' or exists(
      select 1 from public.assignments a where a.id=(storage.foldername(name))[1]::uuid and public.is_teacher_of(a.course_id)
    )
  ));
create policy "students may upload own submissions" on storage.objects for insert to authenticated
  with check(bucket_id='submissions' and (storage.foldername(name))[2]=auth.uid()::text and exists(
    select 1 from public.assignments a join public.courses c on c.id=a.course_id
    where a.id=(storage.foldername(name))[1]::uuid and c.is_active and public.is_enrolled_in(c.id)
  ));

create or replace view public.marks_overview with (security_invoker=true) as
  select s.student_id,a.course_id,'assignment'::text as item_type,a.id as item_id,a.title,s.marks_obtained,a.max_marks,
    round((s.marks_obtained/nullif(a.max_marks,0))*100,2) as percentage,s.graded_at
  from public.submissions s join public.assignments a on a.id=s.assignment_id where s.graded_at is not null and s.marks_obtained is not null
  union all
  select qa.student_id,q.course_id,'quiz'::text,q.id,q.title,qa.score,q.max_marks,
    round((qa.score/nullif(q.max_marks,0))*100,2),qa.submitted_at
  from public.quiz_attempts qa join public.quizzes q on q.id=qa.quiz_id where qa.status='graded' and qa.score is not null;
grant select on public.marks_overview to authenticated;

-- Realtime publication membership is restricted by the same table RLS policies.
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.announcements;
