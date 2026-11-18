create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if not exists (select 1 from public.profiles where id = v_uid and deleted_at is null) then
    perform private.api_error(404, 'user_not_found', 'Akun tidak ditemukan');
  end if;

  perform private.queue_user_files(v_uid, 'account_delete');

  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
  select 'post', id, author_id, body, attachments, v_uid, 'account_delete'
  from public.posts where author_id = v_uid and deleted_at is null;
  update public.posts set deleted_at = now(), body = '', attachments = '[]'::jsonb
   where author_id = v_uid and deleted_at is null;

  insert into private.content_archive (target_type, target_id, author_id, body, deleted_by, reason)
  select 'comment', id, author_id, body, v_uid, 'account_delete'
  from public.comments where author_id = v_uid and deleted_at is null;
  update public.comments set deleted_at = now(), body = ''
   where author_id = v_uid and deleted_at is null;

  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
  select 'message', id, sender_id, body, attachments, v_uid, 'account_delete'
  from public.messages where sender_id = v_uid and deleted_at is null;
  update public.messages set deleted_at = now(), body = '', attachments = '[]'::jsonb
   where sender_id = v_uid and deleted_at is null;

  delete from public.reactions where user_id = v_uid;
  delete from public.follows where follower_id = v_uid or following_id = v_uid;
  delete from public.blocks where blocker_id = v_uid;
  delete from public.mutes where muter_id = v_uid;
  delete from public.muted_keywords where user_id = v_uid;
  delete from public.muted_stocks where user_id = v_uid;
  delete from public.stock_watchers where user_id = v_uid;
  delete from public.chat_members where user_id = v_uid;
  delete from public.notifications where user_id = v_uid or actor_id = v_uid;
  delete from public.user_consents where user_id = v_uid;
  delete from private.user_private where user_id = v_uid;

  update public.profiles
     set username = 'deleted_' || substr(md5(id::text), 1, 12),
         display_name = null, bio = null, avatar_url = null,
         is_verified = false, deleted_at = now()
   where id = v_uid;

  perform private.revoke_sessions(v_uid, 'account_delete');
  perform private.log_personal_data_access(v_uid, 'account_delete', '{all}');
end;
$$;
