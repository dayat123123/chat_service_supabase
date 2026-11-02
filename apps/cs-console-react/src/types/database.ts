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
      admin_agents: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_delete_holiday: { Args: { p_day: string }; Returns: Json }
      admin_holidays: { Args: { p_year: number }; Returns: Json }
      admin_options: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_quick_replies: { Args: Record<PropertyKey, never>; Returns: Json }
      admin_reset_password: { Args: { p_agent_id: string }; Returns: Json }
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
      admin_set_nasabah_permissions: {
        Args: { p_agent_id: string; p_permissions: string[] }
        Returns: Json
      }
      admin_set_setting: {
        Args: { p_key: string; p_value: Json }
        Returns: Json
      }
      admin_settings: { Args: Record<PropertyKey, never>; Returns: Json }
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
      cancel_transfer: { Args: { p_transfer_id: string }; Returns: undefined }
      check_sensitive: { Args: { p_text: string }; Returns: Json }
      claim_ticket: { Args: { p_ticket_id: string }; Returns: Json }
      close_ticket: { Args: { p_ticket_id: string }; Returns: Json }
      compliance_add_banned_word: {
        Args: { p_action: string; p_word: string }
        Returns: Json
      }
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
      compliance_delete_banned_word: { Args: { p_word: string }; Returns: Json }
      compliance_extend_deadline: {
        Args: { p_reason: string; p_ticket_id: string; p_version?: number }
        Returns: Json
      }
      compliance_import_banned_words: { Args: { p_rows: Json }; Returns: Json }
      compliance_overview: { Args: Record<PropertyKey, never>; Returns: Json }
      compliance_policies: { Args: Record<PropertyKey, never>; Returns: Json }
      compliance_review: {
        Args: { p_note: string; p_ticket_id: string; p_verdict: string }
        Returns: Json
      }
      compliance_set_banned_word_action: {
        Args: { p_action: string; p_word: string }
        Returns: Json
      }
      compliance_transcript_exported: {
        Args: { p_messages: number; p_sha256: string; p_ticket_id: string }
        Returns: Json
      }
      customer_history: { Args: { p_customer_id: string }; Returns: Json }
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
      mark_read: { Args: { p_room_id: string }; Returns: undefined }
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
      ticket_customer_login: { Args: { p_ticket_id: string }; Returns: Json }
      ticket_detail: { Args: { p_ticket_id: string }; Returns: Json }
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
