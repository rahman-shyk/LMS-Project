-- LOCAL DEVELOPMENT ONLY. All seed accounts use the temporary password ChangeMe123!.
-- Every seeded profile forces a password change at first sign-in. Never run this on production.
create extension if not exists pgcrypto;
do $$
declare
  people jsonb := '[
    {"id":"10000000-0000-4000-8000-000000000001","name":"Riley Chen","email":"admin@northstar.local","role":"admin"},
    {"id":"10000000-0000-4000-8000-000000000002","name":"Jordan Lee","email":"jordan@northstar.local","role":"teacher"},
    {"id":"10000000-0000-4000-8000-000000000003","name":"Mika Thompson","email":"mika@northstar.local","role":"teacher"},
    {"id":"10000000-0000-4000-8000-000000000004","name":"Avery Morgan","email":"avery@northstar.local","role":"student","roll":"NS-24018"},
    {"id":"10000000-0000-4000-8000-000000000005","name":"Kai Bennett","email":"kai@northstar.local","role":"student","roll":"NS-24019"},
    {"id":"10000000-0000-4000-8000-000000000006","name":"Sam Rivera","email":"sam@northstar.local","role":"student","roll":"NS-24020"},
    {"id":"10000000-0000-4000-8000-000000000007","name":"Noor Patel","email":"noor@northstar.local","role":"student","roll":"NS-24021"},
    {"id":"10000000-0000-4000-8000-000000000008","name":"Eli Brooks","email":"eli@northstar.local","role":"student","roll":"NS-24022"}
  ]'::jsonb;
  person jsonb;
begin
  for person in select value from jsonb_array_elements(people) loop
    insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
    values((person->>'id')::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',person->>'email',crypt('ChangeMe123!',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}',jsonb_build_object('full_name',person->>'name'),now(),now())
    on conflict(id) do nothing;
    insert into auth.identities(id,user_id,identity_data,provider,provider_id,created_at,updated_at)
    values(gen_random_uuid(),(person->>'id')::uuid,jsonb_build_object('sub',person->>'id','email',person->>'email'),'email',person->>'id',now(),now())
    on conflict(provider_id,provider) do nothing;
    insert into public.profiles(id,full_name,email,role,roll_number,is_active,must_change_password)
    values((person->>'id')::uuid,person->>'name',person->>'email',(person->>'role')::public.user_role,person->>'roll',true,true)
    on conflict(id) do nothing;
  end loop;
end $$;

insert into public.courses(id,code,title,description,teacher_id) values
 ('20000000-0000-4000-8000-000000000001','DS-204','Data & Society','How data shapes the world, and how we shape data.', '10000000-0000-4000-8000-000000000002'),
 ('20000000-0000-4000-8000-000000000002','UX-118','Human-centered Design','A studio course in listening, prototyping, and iteration.', '10000000-0000-4000-8000-000000000003')
on conflict(id) do nothing;
insert into public.enrollments(course_id,student_id) select c.id,p.id from public.courses c cross join public.profiles p where c.code='DS-204' and p.role='student' on conflict(course_id,student_id) do nothing;
insert into public.enrollments(course_id,student_id) select c.id,p.id from public.courses c cross join public.profiles p where c.code='UX-118' and p.role='student' on conflict(course_id,student_id) do nothing;
