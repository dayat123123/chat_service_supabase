create or replace function cs.legal_draft_view(p_id uuid, p_with_body boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', d.id, 'kind', d.kind, 'title', d.title,
    'body', case when p_with_body then d.body end,
    'body_length', char_length(d.body),
    'change_summary', d.change_summary, 'effective_at', d.effective_at, 'status', d.status,
    'created_by', cs.agent_name(d.created_by), 'created_by_id', d.created_by, 'created_at', d.created_at,
    'updated_by', cs.agent_name(d.updated_by), 'updated_by_id', d.updated_by, 'updated_at', d.updated_at,
    'submitted_by', cs.agent_name(d.submitted_by), 'submitted_by_id', d.submitted_by, 'submitted_at', d.submitted_at,
    'reviewed_by', cs.agent_name(d.reviewed_by), 'reviewed_at', d.reviewed_at, 'review_note', d.review_note,
    'document_id', d.document_id))
  from cs.legal_drafts d
  where d.id = p_id;
$$;
