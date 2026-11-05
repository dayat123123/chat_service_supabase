export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  cs_api: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      add_note: {
        Args: { p_body: string; p_customer_id?: string; p_ticket_id?: string }
        Returns: Json
      }
      add_ticket_label: { Args: { p_label_id: string; p_ticket_id: string }; Returns: Json }
      admin_agents: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_analytics: {
        Args: { p_from?: string; p_to?: string }
        Returns: Json
      }
      admin_banner_settings: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_banner_stats: { Args: { p_id: string }; Returns: Json }
      admin_banners: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_delete_banner: { Args: { p_id: string }; Returns: Json }
      admin_delete_feature_flag: { Args: { p_key: string }; Returns: Json }
      admin_delete_holiday: { Args: { p_day: string }; Returns: Json }
      admin_feature_flags: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_holidays: { Args: { p_year: number }; Returns: Json }
      admin_options: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_policy_four_eyes: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      admin_quick_replies: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_reorder_ticket_labels: { Args: { p_ids: string[] }; Returns: Json }
      admin_reset_password: { Args: { p_agent_id: string }; Returns: Json }
      admin_save_banner: {
        Args: {
          p_audience?: string
          p_audience_days?: number
          p_body?: string
          p_cta_label?: string
          p_dismissible?: boolean
          p_display?: string
          p_ends_at?: string
          p_frequency?: string
          p_id: string
          p_image_url?: string
          p_level?: string
          p_link_url?: string
          p_max_app_version?: string
          p_min_app_version?: string
          p_platforms?: string[]
          p_priority?: number
          p_starts_at?: string
          p_title: string
        }
        Returns: Json
      }
      admin_save_holiday: {
        Args: { p_day: string; p_kind: string; p_name: string }
        Returns: Json
      }
      admin_save_quick_reply: {
        Args: {
          p_active: boolean
          p_body: string
          p_id: string
          p_language: string
          p_shortcut: string
          p_title: string
        }
        Returns: Json
      }
      admin_save_ticket_label: { Args: { p_active: boolean; p_color: string; p_id: string; p_name: string }; Returns: Json }
      admin_save_topic: {
        Args: {
          p_active: boolean
          p_code: string
          p_default_priority: string
          p_help_url: string
          p_name_en: string
          p_name_id: string
          p_skill: string
          p_sort_order: number
        }
        Returns: Json
      }
      admin_set_banner_link_schemes: { Args: { p_schemes: string[] }; Returns: Json }
      admin_set_community_permissions: {
        Args: { p_agent_id: string; p_permissions: string[] }
        Returns: Json
      }
      admin_set_feature_flag: {
        Args: {
          p_description?: string
          p_enabled: boolean
          p_key: string
          p_min_app_version?: string
          p_percentage?: number
          p_platforms?: string[]
          p_user_ids?: string[]
        }
        Returns: Json
      }
      admin_set_kill_switch: {
        Args: { p_enabled: boolean; p_reason: string }
        Returns: Json
      }
      admin_set_min_version: {
        Args: { p_min_version: string; p_platform: string }
        Returns: Json
      }
      admin_set_nasabah_permissions: {
        Args: { p_agent_id: string; p_permissions: string[] }
        Returns: Json
      }
      admin_set_policy_four_eyes: {
        Args: { p_enabled: boolean }
        Returns: Json
      }
      admin_set_setting: {
        Args: { p_key: string; p_value: Json }
        Returns: Json
      }
      admin_settings: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_ticket_labels: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_toggle_feature_flag: {
        Args: { p_enabled: boolean; p_key: string }
        Returns: Json
      }
      admin_topics: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_update_agent: {
        Args: {
          p_agent_id: string
          p_disabled: boolean
          p_display_name: string
          p_max_active_tickets: number
          p_roles: string[]
          p_team: string
        }
        Returns: Json
      }
      agent_heartbeat: { Args: Record<PropertyKey, never>; Returns: Json }
      agent_me: { Args: Record<PropertyKey, never>; Returns: Json }
      agent_my_profile: { Args: Record<PropertyKey, never>; Returns: Json }
      agent_my_stats: { Args: { p_period: string }; Returns: Json }
      agent_password_changed: { Args: Record<PropertyKey, never>; Returns: Json }
      agent_send_message: {
        Args: {
          p_attachments?: Json
          p_body: string
          p_client_id?: string
          p_kind?: string
          p_payload?: Json
          p_reply_to_id?: string
          p_ticket_id: string
        }
        Returns: Json
      }
      agent_set_status: {
        Args: { p_reason?: string; p_status: string }
        Returns: Json
      }
      agent_signed_out_everywhere: { Args: Record<PropertyKey, never>; Returns: Json }
      agent_typing: {
        Args: { p_room_id: string; p_typing?: boolean }
        Returns: boolean
      }
      alert_channels_view: { Args: Record<PropertyKey, never>; Returns: Json }
      alert_send_test: { Args: { p_channel: string }; Returns: Json }
      alert_set_email: {
        Args: {
          p_enabled: boolean
          p_from: string
          p_host: string
          p_password?: string
          p_port: number
          p_security: string
          p_to: string[]
          p_username: string
        }
        Returns: Json
      }
      alert_set_options: {
        Args: { p_console_url: string; p_label: string }
        Returns: Json
      }
      alert_set_telegram: {
        Args: { p_bot_token?: string; p_chat_ids: string[]; p_enabled: boolean }
        Returns: Json
      }
      app_integration_overview: { Args: Record<PropertyKey, never>; Returns: Json }
      backup_overview: { Args: Record<PropertyKey, never>; Returns: Json }
      backup_request: { Args: { p_kind: string }; Returns: Json }
      backup_set_schedule: {
        Args: {
          p_base_time: string
          p_offsite_minutes: number
          p_restore_test: boolean
          p_restore_test_time: string
          p_restore_test_weekday: number
          p_retention_daily: number
          p_retention_monthly: number
          p_retention_weekly: number
          p_wal_days: number
        }
        Returns: Json
      }
      backup_set_target: {
        Args: {
          p_access_key_id?: string
          p_bucket?: string
          p_endpoint?: string
          p_kind?: string
          p_password?: string
          p_prefix?: string
          p_region?: string
          p_secret_access_key?: string
        }
        Returns: Json
      }
      cancel_transfer: { Args: { p_transfer_id: string }; Returns: undefined }
      check_sensitive: { Args: { p_text: string }; Returns: Json }
      claim_ticket: { Args: { p_ticket_id: string }; Returns: Json }
      close_ticket: { Args: { p_ticket_id: string }; Returns: Json }
      community_accounts: { Args: Record<PropertyKey, never>; Returns: Json }
      community_appeal_decide: {
        Args: { p_accept: boolean; p_id: string; p_note: string }
        Returns: Json
      }
      community_appeals: {
        Args: { p_limit?: number; p_status?: string }
        Returns: Json
      }
      community_appoint_room_moderator: {
        Args: { p_code: string; p_note?: string; p_user_id: string }
        Returns: Json
      }
      community_audience_size: {
        Args: {
          p_account_id?: string
          p_audience: string
          p_days?: number
          p_platform?: string
          p_stock?: string
        }
        Returns: number
      }
      community_campaign_push: { Args: { p_id: string }; Returns: Json }
      community_campaigns: { Args: { p_status?: string }; Returns: Json }
      community_cancel_campaign: {
        Args: { p_id: string; p_version?: number }
        Returns: Json
      }
      community_cancel_post: {
        Args: { p_id: string; p_version?: number }
        Returns: Json
      }
      community_content: {
        Args: { p_id: string; p_type: string }
        Returns: Json
      }
      community_content_meta: { Args: { p_targets: Json }; Returns: Json }
      community_delete_post: {
        Args: { p_id: string; p_reason: string }
        Returns: Json
      }
      community_edit_history: {
        Args: { p_target_id: string; p_target_type: string }
        Returns: Json
      }
      community_find_users: { Args: { p_query: string }; Returns: Json }
      community_held_content: { Args: { p_limit?: number }; Returns: Json }
      community_manipulation_alerts: {
        Args: { p_limit?: number; p_status?: string; p_stock?: string }
        Returns: Json
      }
      community_manipulation_review: {
        Args: { p_id: string; p_note: string; p_status: string }
        Returns: Json
      }
      community_media_review_decide: {
        Args: { p_decision: string; p_id: number; p_note?: string }
        Returns: Json
      }
      community_media_reviews: {
        Args: { p_cursor?: number; p_limit?: number; p_status?: string }
        Returns: Json
      }
      community_overview: { Args: Record<PropertyKey, never>; Returns: Json }
      community_pin_message: {
        Args: { p_message: string; p_room: string }
        Returns: Json
      }
      community_pin_post: {
        Args: {
          p_id: string
          p_scope: string
          p_stock?: string
          p_until?: string
        }
        Returns: Json
      }
      community_posts: { Args: { p_status?: string }; Returns: Json }
      community_remove_room_moderator: {
        Args: { p_code: string; p_reason: string; p_user_id: string }
        Returns: Json
      }
      community_reports: {
        Args: { p_limit?: number; p_status?: string }
        Returns: Json
      }
      community_resolve_report: {
        Args: {
          p_action: string
          p_reason: string
          p_target_id: string
          p_target_type: string
        }
        Returns: Json
      }
      community_review_campaign: {
        Args: {
          p_approve: boolean
          p_id: string
          p_note?: string
          p_version?: number
        }
        Returns: Json
      }
      community_review_post: {
        Args: {
          p_approve: boolean
          p_id: string
          p_note?: string
          p_version?: number
        }
        Returns: Json
      }
      community_revoke_sanction: {
        Args: { p_reason: string; p_sanction_id: string }
        Returns: Json
      }
      community_revoke_sessions: {
        Args: { p_reason: string; p_user_id: string }
        Returns: Json
      }
      community_room_messages: {
        Args: {
          p_before?: string
          p_before_id?: string
          p_code: string
          p_limit?: number
        }
        Returns: Json
      }
      community_room_moderator_actions: {
        Args: {
          p_before?: string
          p_before_id?: string
          p_code?: string
          p_limit?: number
        }
        Returns: Json
      }
      community_room_moderator_candidates: {
        Args: { p_code: string; p_query: string }
        Returns: Json
      }
      community_room_moderator_settings: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      community_room_moderators: { Args: { p_code: string }; Returns: Json }
      community_room_settings: {
        Args: { p_code: string; p_slow_mode_seconds: number; p_until?: string }
        Returns: Json
      }
      community_room_state: { Args: { p_code: string }; Returns: Json }
      community_sanction_user: {
        Args: {
          p_duration_hours?: number
          p_kind?: string
          p_reason: string
          p_user_id: string
        }
        Returns: Json
      }
      community_save_account: {
        Args: {
          p_avatar_url?: string
          p_bio?: string
          p_display_name: string
          p_id: string
          p_username: string
        }
        Returns: Json
      }
      community_save_campaign: {
        Args: {
          p_account_id: string
          p_audience?: string
          p_audience_account_id?: string
          p_audience_days?: number
          p_audience_platform?: string
          p_audience_stock?: string
          p_body: string
          p_id: string
          p_link_post_id?: string
          p_link_url?: string
          p_send_at?: string
          p_title: string
          p_version?: number
        }
        Returns: Json
      }
      community_save_post: {
        Args: {
          p_account_id: string
          p_attachments?: Json
          p_body: string
          p_id: string
          p_kind: string
          p_notify?: boolean
          p_pin_scope?: string
          p_pin_stock?: string
          p_pin_until?: string
          p_publish_at?: string
          p_title: string
          p_version?: number
        }
        Returns: Json
      }
      community_set_account_disabled: {
        Args: { p_disabled: boolean; p_id: string }
        Returns: Json
      }
      community_set_room_moderator_settings: {
        Args: { p_values: Json }
        Returns: Json
      }
      community_set_verified: {
        Args: { p_reason: string; p_user_id: string; p_verified: boolean }
        Returns: Json
      }
      community_submit_campaign: {
        Args: { p_id: string; p_version?: number }
        Returns: Json
      }
      community_submit_post: {
        Args: { p_id: string; p_version?: number }
        Returns: Json
      }
      community_undo_room_moderator_action: {
        Args: { p_id: string; p_note: string }
        Returns: Json
      }
      community_user: { Args: { p_user_id: string }; Returns: Json }
      community_zero_tolerance: {
        Args: { p_reason: string; p_user_id: string }
        Returns: Json
      }
      compliance_add_allowlist_term: { Args: { p_term: string }; Returns: Json }
      compliance_add_banned_word: {
        Args: { p_action: string; p_word: string }
        Returns: Json
      }
      compliance_add_promo_phrase: { Args: { p_phrase: string }; Returns: Json }
      compliance_audit: {
        Args: {
          p_action?: string
          p_before_at?: string
          p_before_id?: number
          p_from: string
          p_limit?: number
          p_query?: string
          p_to: string
        }
        Returns: Json
      }
      compliance_banned_words: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      compliance_case: { Args: { p_ticket_id: string }; Returns: Json }
      compliance_cases: {
        Args: {
          p_from?: string
          p_kind?: string
          p_query?: string
          p_state?: string
          p_to?: string
        }
        Returns: Json
      }
      compliance_confirm_policy: {
        Args: { p_key: string; p_note?: string; p_value: Json }
        Returns: Json
      }
      compliance_content_rules: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      compliance_delete_allowed_domain: {
        Args: { p_domain: string }
        Returns: Json
      }
      compliance_delete_allowlist_term: {
        Args: { p_term: string }
        Returns: Json
      }
      compliance_delete_banned_word: { Args: { p_word: string }; Returns: Json }
      compliance_delete_blocked_domain: {
        Args: { p_domain: string }
        Returns: Json
      }
      compliance_delete_promo_phrase: {
        Args: { p_phrase: string }
        Returns: Json
      }
      compliance_extend_deadline: {
        Args: { p_reason: string; p_ticket_id: string; p_version?: number }
        Returns: Json
      }
      compliance_image_thresholds: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      compliance_import_banned_words: { Args: { p_rows: Json }; Returns: Json }
      compliance_manipulation_settings: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      compliance_overview: { Args: Record<PropertyKey, never>; Returns: Json }
      compliance_policies: { Args: Record<PropertyKey, never>; Returns: Json }
      compliance_policy_call: {
        Args: { p_args?: Json; p_fn: string }
        Returns: Json
      }
      compliance_policy_change: { Args: { p_id: number }; Returns: Json }
      compliance_policy_changes: {
        Args: { p_limit?: number; p_status?: string }
        Returns: Json
      }
      compliance_policy_decide: {
        Args: { p_approve: boolean; p_id: number; p_note?: string }
        Returns: Json
      }
      compliance_policy_discard: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      compliance_policy_rollback: {
        Args: { p_reason: string; p_version: number }
        Returns: Json
      }
      compliance_policy_simulate: {
        Args: {
          p_change_id?: number
          p_days?: number
          p_limit?: number
          p_surface?: string
          p_text?: string
          p_version?: number
        }
        Returns: Json
      }
      compliance_policy_state: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      compliance_policy_submit: { Args: { p_reason: string }; Returns: Json }
      compliance_policy_version: { Args: { p_version: number }; Returns: Json }
      compliance_policy_versions: {
        Args: { p_before?: number; p_limit?: number }
        Returns: Json
      }
      compliance_policy_withdraw: { Args: { p_id: number }; Returns: Json }
      compliance_review: {
        Args: { p_note: string; p_ticket_id: string; p_verdict: string }
        Returns: Json
      }
      compliance_save_allowed_domain: {
        Args: { p_domain: string; p_note?: string }
        Returns: Json
      }
      compliance_save_blocked_domain: {
        Args: {
          p_action?: string
          p_category: string
          p_domain: string
          p_match?: string
          p_note?: string
        }
        Returns: Json
      }
      compliance_set_banned_word_action: {
        Args: { p_action: string; p_word: string }
        Returns: Json
      }
      compliance_set_content_rule: {
        Args: { p_action: string; p_category: string; p_scope?: string }
        Returns: Json
      }
      compliance_set_image_thresholds: {
        Args: { p_note?: string; p_thresholds: Json }
        Returns: Json
      }
      compliance_set_manipulation_settings: {
        Args: { p_values: Json }
        Returns: Json
      }
      compliance_set_new_account_days: {
        Args: { p_days: number }
        Returns: Json
      }
      compliance_test_content: {
        Args: { p_surface?: string; p_text: string }
        Returns: Json
      }
      compliance_transcript_exported: {
        Args: { p_messages: number; p_sha256: string; p_ticket_id: string }
        Returns: Json
      }
      customer_history: { Args: { p_customer_id: string }; Returns: Json }
      delete_my_quick_reply: { Args: { p_id: string }; Returns: Json }
      evidence_detail: { Args: { p_id: string }; Returns: Json }
      evidence_export: {
        Args: { p_id: string; p_purpose: string }
        Returns: Json
      }
      evidence_file_checked: {
        Args: { p_file_id: number; p_sha256: string }
        Returns: Json
      }
      evidence_list: {
        Args: {
          p_before_seq?: number
          p_filter?: string
          p_limit?: number
          p_query?: string
          p_source?: string
        }
        Returns: Json
      }
      evidence_set_hold: {
        Args: { p_hold: boolean; p_id: string; p_reason: string }
        Returns: Json
      }
      evidence_verify: { Args: { p_id: string }; Returns: Json }
      flag_ticket: {
        Args: { p_flag: string; p_ticket_id: string }
        Returns: Json
      }
      get_messages: {
        Args: {
          p_after?: string
          p_cursor?: string
          p_limit?: number
          p_room_id: string
        }
        Returns: unknown[]
        SetofOptions: {
          from: "*"
          to: "chat_message"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      healer_overview: { Args: Record<PropertyKey, never>; Returns: Json }
      health_acknowledge: { Args: { p_alert_id: number }; Returns: undefined }
      integration_broadcasts: {
        Args: { p_key_id?: string; p_limit?: number }
        Returns: Json
      }
      integration_key_create: {
        Args: {
          p_allowed_cidrs?: string[]
          p_name: string
          p_official_account_id?: string
          p_rate_limit_per_minute?: number
          p_scopes: string[]
        }
        Returns: Json
      }
      integration_key_revoke: {
        Args: { p_id: string; p_reason: string }
        Returns: Json
      }
      integration_key_update: {
        Args: {
          p_allowed_cidrs?: string[]
          p_enabled?: boolean
          p_id: string
          p_name: string
          p_official_account_id?: string
          p_rate_limit_per_minute?: number
          p_scopes: string[]
        }
        Returns: Json
      }
      integration_keys: { Args: Record<PropertyKey, never>; Returns: Json }
      integration_official_accounts: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      integration_stats: { Args: { p_days?: number }; Returns: Json }
      integration_stats_daily: {
        Args: { p_days?: number; p_key_id?: string }
        Returns: Json
      }
      legal_cancel_scheduled: { Args: { p_document_id: string }; Returns: Json }
      legal_document: { Args: { p_id: string }; Returns: Json }
      legal_draft: { Args: { p_id: string }; Returns: Json }
      legal_draft_approve: { Args: { p_id: string }; Returns: Json }
      legal_draft_delete: { Args: { p_id: string }; Returns: undefined }
      legal_draft_reject: {
        Args: { p_id: string; p_note: string }
        Returns: Json
      }
      legal_draft_save: {
        Args: {
          p_body: string
          p_change_summary?: string
          p_effective_at?: string
          p_id: string
          p_kind: string
          p_title: string
        }
        Returns: Json
      }
      legal_draft_submit: { Args: { p_id: string }; Returns: Json }
      legal_draft_withdraw: { Args: { p_id: string }; Returns: Json }
      legal_overview: { Args: Record<PropertyKey, never>; Returns: Json }
      legal_set_required: { Args: { p_kinds: string[] }; Returns: Json }
      mark_read: { Args: { p_room_id: string }; Returns: undefined }
      my_quick_replies: { Args: Record<PropertyKey, never>; Returns: Json }
      my_tickets: { Args: Record<PropertyKey, never>; Returns: Json }
      nasabah_access: { Args: { p_user_id: string }; Returns: Json }
      nasabah_audit: {
        Args: { p_action: string; p_details: Json; p_user_id: string }
        Returns: undefined
      }
      nasabah_clear_integration: { Args: { p_user_id: string }; Returns: Json }
      nasabah_integration: { Args: Record<PropertyKey, never>; Returns: Json }
      nasabah_is_super_admin: { Args: { p_user_id: string }; Returns: boolean }
      nasabah_save_integration: {
        Args: { p_client_id: string; p_url: string; p_user_id: string }
        Returns: Json
      }
      notes: { Args: { p_customer_id: string }; Returns: Json }
      online_agents: { Args: Record<PropertyKey, never>; Returns: Json }
      open_ticket: {
        Args: {
          p_complaint?: boolean
          p_language?: string
          p_screen?: string
          p_topic: string
        }
        Returns: Json
      }
      push_find_users: { Args: { p_query: string }; Returns: Json }
      push_remove_credentials: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      push_set_credentials: {
        Args: { p_credentials: Json; p_replace_project?: boolean }
        Returns: Json
      }
      push_status: { Args: Record<PropertyKey, never>; Returns: Json }
      push_test: { Args: { p_user_id: string }; Returns: Json }
      quick_replies: { Args: { p_language?: string }; Returns: Json }
      rate_ticket: {
        Args: { p_comment?: string; p_rating: number; p_ticket_id: string }
        Returns: Json
      }
      reassign_ticket: {
        Args: { p_reason: string; p_ticket_id: string; p_to_agent_id: string }
        Returns: Json
      }
      release_ticket: {
        Args: { p_reason: string; p_ticket_id: string; p_version?: number }
        Returns: Json
      }
      remove_ticket_label: { Args: { p_label_id: string; p_ticket_id: string }; Returns: Json }
      report_customer_trail: {
        Args: { p_customer_id: string; p_from: string; p_to: string }
        Returns: Json
      }
      report_customers: {
        Args: { p_from: string; p_search?: string; p_to: string }
        Returns: Json
      }
      report_fake_cs: { Args: { p_description: string }; Returns: Json }
      report_summary: { Args: { p_from: string; p_to: string }; Returns: Json }
      report_ticket_labels: { Args: { p_from: string; p_to: string }; Returns: Json }
      request_complaint: { Args: Record<PropertyKey, never>; Returns: Json }
      request_transfer: {
        Args: {
          p_note: string
          p_ticket_id: string
          p_to_agent_id: string
          p_version?: number
        }
        Returns: Json
      }
      resolve_ticket: {
        Args: {
          p_outcome: string
          p_summary: string
          p_tags?: string[]
          p_ticket_id: string
          p_version?: number
        }
        Returns: Json
      }
      respond_transfer: {
        Args: { p_accept: boolean; p_reason?: string; p_transfer_id: string }
        Returns: Json
      }
      room_members: { Args: { p_room_id: string }; Returns: Json }
      save_my_quick_reply: { Args: { p_body: string; p_id: string; p_shortcut?: string; p_title: string }; Returns: Json }
      search_tickets: { Args: { p_query: string }; Returns: Json }
      send_message: {
        Args: {
          p_attachments?: Json
          p_body: string
          p_client_id?: string
          p_reply_to_id?: string
          p_room_id: string
        }
        Returns: unknown[]
        SetofOptions: {
          from: "*"
          to: "chat_message"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      service_create_agent: {
        Args: {
          p_created_by: string
          p_display_name: string
          p_max_active_tickets: number
          p_roles: string[]
          p_team: string
          p_user_id: string
        }
        Returns: Json
      }
      set_ticket_priority: {
        Args: { p_priority: string; p_ticket_id: string; p_version?: number }
        Returns: Json
      }
      supervisor_overview: { Args: Record<PropertyKey, never>; Returns: Json }
      support_home: { Args: Record<PropertyKey, never>; Returns: Json }
      system_health: { Args: Record<PropertyKey, never>; Returns: Json }
      system_health_badge: { Args: Record<PropertyKey, never>; Returns: Json }
      ticket_customer_login: { Args: { p_ticket_id: string }; Returns: Json }
      ticket_detail: { Args: { p_ticket_id: string }; Returns: Json }
      ticket_labels: { Args: Record<PropertyKey, never>; Returns: Json }
      ticket_lists: { Args: Record<PropertyKey, never>; Returns: Json }
      ticket_messages: {
        Args: { p_ticket_id: string }
        Returns: unknown[]
        SetofOptions: {
          from: "*"
          to: "chat_message"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      topics: { Args: { p_language?: string }; Returns: Json }
      wait_customer: {
        Args: { p_ticket_id: string; p_version?: number }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  cs_api: {
    Enums: {},
  },
} as const
