begin;

alter table public.device_tokens
  add column if not exists device_id text;

update public.device_tokens
set device_id = 'legacy:' || fcm_token
where device_id is null or device_id = '';

alter table public.device_tokens
  alter column device_id set not null;

alter table public.device_tokens
  drop constraint if exists device_tokens_pkey;

alter table public.device_tokens
  add constraint device_tokens_pkey primary key (user_id, device_id);

create index if not exists device_tokens_fcm_token_idx
  on public.device_tokens (fcm_token);

create index if not exists device_tokens_user_updated_at_idx
  on public.device_tokens (user_id, updated_at desc);

commit;
