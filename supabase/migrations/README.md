# TotalKudzu V1 Database Schema

Multi-tenant Time-Off + Time Tracking SaaS database schema for Supabase (Postgres).

## Quick Start

```bash
# Reset database and apply all migrations
supabase db reset

# Or apply migrations manually
supabase db push
```

## Migration Files

| File | Description |
|------|-------------|
| `0001_init.sql` | Extensions (pgcrypto, citext), helper functions, base tables (profile, company, company_member) |
| `0002_org.sql` | Organization structure (office, department, member_office, member_department, work_schedule) |
| `0003_holidays.sql` | Holiday calendars, holidays, office assignments, overrides |
| `0004_approvals.sql` | Approval rules with inheritance (member → department → company default) |
| `0005_leave.sql` | Leave types, policies, requests, approvals, ledger, balance snapshots |
| `0006_time_tracking.sql` | Projects, tasks, time entries, timer sessions |
| `0007_timesheets.sql` | Timesheet periods, submissions, approvals |
| `0008_audit.sql` | Audit log for all changes |
| `0009_triggers.sql` | All triggers (12 total) |
| `seed.sql` | Holiday calendars for US, BG, GB, DE, FR |

## Key Design Decisions

- **Identity**: Uses Supabase Auth (`auth.users`) with `profile` extension table
- **Multi-tenancy**: RLS on all tables using `company_id` + membership checks
- **Primary Department**: Stored only in `member_department.is_primary` (no denormalized column)
- **Primary Office**: Bidirectional sync between `company_member.primary_office_id` and `member_office.is_primary`
- **Leave Balances**: Ledger + Snapshot pattern for accurate tracking
- **Duration**: Computed-only (`end_time - start_time`), no manual override
- **Table Naming**: Singular throughout (e.g., `leave_request`, not `leave_requests`)

## Triggers

1. `trg_set_updated_at` - Auto-update timestamps
2. `trg_sync_primary_office` - Bidirectional primary office sync
3. `trg_validate_leave_department` - Block leave without primary department
4. `trg_timesheet_reapproval` - Mark timesheets as needs_reapproval on entry changes
5. `trg_leave_ledger_on_approval` - Create usage transaction on approval
6. `trg_leave_ledger_reversal` - Create reversal on cancellation
7. `trg_update_balance_snapshot` - Update balance snapshots
8. `trg_update_pending_minutes` - Track pending leave requests
9. `trg_leave_ledger_immutable` - Prevent ledger modifications
10. `trg_compute_duration` - Auto-compute time entry duration
11. `trg_audit_log` - Audit trail for all tables
12. `trg_create_leave_approval` - Auto-create approval record

## RLS Notes

All tables have RLS enabled. Key patterns:
- Members can view data in their company
- Admins can modify company data
- Users can modify their own records (requests, entries)
- Approvers can view/modify records assigned to them
