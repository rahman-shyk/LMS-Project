-- Complaint attachments are private and available only to the submitter and administrators.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
  ('complaints','complaints',false,20971520,array['application/pdf','image/png','image/jpeg'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "complaint owners and admins may read attachments" on storage.objects;
create policy "complaint owners and admins may read attachments" on storage.objects for select to authenticated
  using(bucket_id='complaints' and ((storage.foldername(name))[1]=auth.uid()::text or public.current_role()='admin'));

drop policy if exists "users upload own complaint attachments" on storage.objects;
create policy "users upload own complaint attachments" on storage.objects for insert to authenticated
  with check(bucket_id='complaints' and (storage.foldername(name))[1]=auth.uid()::text);
