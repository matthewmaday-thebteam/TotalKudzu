// User Management Types
export type UserRole = 'admin' | 'user';

// Date Range Type
export interface DateRange {
  start: Date;
  end: Date;
}

// Holiday Types (for HolidayCalendar demo)
export interface BulgarianHoliday {
  id: string;
  holiday_date: string;
  holiday_name: string;
  is_system_generated: boolean;
  year: number;
  created_at: string;
  updated_at: string;
}

export interface EmployeeTimeOff {
  id: string;
  start_date: string;
  end_date: string;
}

export interface AppUser {
  id: string;
  email: string;
  display_name: string;
  role: UserRole;
  is_verified: boolean;
  created_at: string;
  last_sign_in_at: string | null;
}

export interface CreateUserParams {
  email: string;
  password?: string | null;
  display_name?: string | null;
  role?: UserRole;
  send_invite?: boolean;
}

export interface CreateUserResult {
  success: boolean;
  user_id: string;
  email: string;
  role: UserRole;
  is_verified: boolean;
  requires_invite: boolean;
}

export interface UpdateRoleResult {
  success: boolean;
  user_id: string;
  previous_role: UserRole;
  new_role: UserRole;
}

export interface DeleteUserResult {
  success: boolean;
  deleted_user_id: string;
  deleted_email: string;
}
