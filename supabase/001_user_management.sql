-- =============================================================================
-- TotalKudzu - User Management Database Setup
-- =============================================================================
-- Run this in Supabase SQL Editor
--
-- Prerequisites:
-- 1. Enable the "supabase_auth_admin" extension (usually enabled by default)
-- 2. Make sure you have service_role access for admin functions
-- =============================================================================

-- Create user_role enum type
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('admin', 'user');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- =============================================================================
-- FUNCTION: admin_list_users
-- Lists all users with their roles and metadata
-- =============================================================================
CREATE OR REPLACE FUNCTION admin_list_users()
RETURNS TABLE (
    id uuid,
    email text,
    display_name text,
    role text,
    is_verified boolean,
    created_at timestamptz,
    last_sign_in_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    calling_user_role text;
BEGIN
    -- Check if the calling user is an admin
    SELECT COALESCE(raw_user_meta_data->>'role', 'user')
    INTO calling_user_role
    FROM auth.users
    WHERE auth.users.id = auth.uid();

    IF calling_user_role != 'admin' THEN
        RAISE EXCEPTION 'Access denied. Admin role required.';
    END IF;

    -- Return all users
    RETURN QUERY
    SELECT
        u.id,
        u.email::text,
        COALESCE(u.raw_user_meta_data->>'display_name', '')::text as display_name,
        COALESCE(u.raw_user_meta_data->>'role', 'user')::text as role,
        (u.email_confirmed_at IS NOT NULL) as is_verified,
        u.created_at,
        u.last_sign_in_at
    FROM auth.users u
    ORDER BY u.created_at DESC;
END;
$$;

-- =============================================================================
-- FUNCTION: admin_create_user
-- Creates a new user with optional password or invite
-- =============================================================================
CREATE OR REPLACE FUNCTION admin_create_user(
    p_email text,
    p_password text DEFAULT NULL,
    p_display_name text DEFAULT NULL,
    p_role text DEFAULT 'admin',
    p_send_invite boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    calling_user_role text;
    new_user_id uuid;
    result jsonb;
BEGIN
    -- Check if the calling user is an admin
    SELECT COALESCE(raw_user_meta_data->>'role', 'user')
    INTO calling_user_role
    FROM auth.users
    WHERE auth.users.id = auth.uid();

    IF calling_user_role != 'admin' THEN
        RAISE EXCEPTION 'Access denied. Admin role required.';
    END IF;

    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'A user with this email already exists.';
    END IF;

    -- Generate a new UUID for the user
    new_user_id := gen_random_uuid();

    -- Insert the new user
    INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        aud,
        role,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token
    )
    VALUES (
        new_user_id,
        '00000000-0000-0000-0000-000000000000',
        p_email,
        CASE
            WHEN p_password IS NOT NULL AND p_password != ''
            THEN crypt(p_password, gen_salt('bf'))
            ELSE ''
        END,
        CASE
            WHEN p_password IS NOT NULL AND p_password != '' AND NOT p_send_invite
            THEN NOW()
            ELSE NULL
        END,
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        jsonb_build_object(
            'role', p_role,
            'display_name', COALESCE(p_display_name, '')
        ),
        'authenticated',
        'authenticated',
        NOW(),
        NOW(),
        CASE WHEN p_send_invite THEN encode(gen_random_bytes(32), 'hex') ELSE '' END,
        ''
    );

    -- Create identity record
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    )
    VALUES (
        gen_random_uuid(),
        new_user_id,
        jsonb_build_object('sub', new_user_id::text, 'email', p_email),
        'email',
        new_user_id::text,
        NOW(),
        NOW(),
        NOW()
    );

    -- Build result
    result := jsonb_build_object(
        'success', true,
        'user_id', new_user_id,
        'email', p_email,
        'role', p_role,
        'is_verified', (p_password IS NOT NULL AND p_password != '' AND NOT p_send_invite),
        'requires_invite', p_send_invite
    );

    RETURN result;
END;
$$;

-- =============================================================================
-- FUNCTION: admin_update_user_role
-- Updates a user's role
-- =============================================================================
CREATE OR REPLACE FUNCTION admin_update_user_role(
    p_user_id uuid,
    p_new_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    calling_user_role text;
    target_user record;
    admin_count integer;
    result jsonb;
BEGIN
    -- Check if the calling user is an admin
    SELECT COALESCE(raw_user_meta_data->>'role', 'user')
    INTO calling_user_role
    FROM auth.users
    WHERE auth.users.id = auth.uid();

    IF calling_user_role != 'admin' THEN
        RAISE EXCEPTION 'Access denied. Admin role required.';
    END IF;

    -- Get the target user
    SELECT id, raw_user_meta_data
    INTO target_user
    FROM auth.users
    WHERE id = p_user_id;

    IF target_user.id IS NULL THEN
        RAISE EXCEPTION 'User not found.';
    END IF;

    -- If demoting from admin, check we're not removing the last admin
    IF COALESCE(target_user.raw_user_meta_data->>'role', 'user') = 'admin' AND p_new_role != 'admin' THEN
        SELECT COUNT(*)
        INTO admin_count
        FROM auth.users
        WHERE raw_user_meta_data->>'role' = 'admin';

        IF admin_count <= 1 THEN
            RAISE EXCEPTION 'Cannot remove the last admin user.';
        END IF;
    END IF;

    -- Update the user's role
    UPDATE auth.users
    SET
        raw_user_meta_data = raw_user_meta_data || jsonb_build_object('role', p_new_role),
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Build result
    result := jsonb_build_object(
        'success', true,
        'user_id', p_user_id,
        'previous_role', COALESCE(target_user.raw_user_meta_data->>'role', 'user'),
        'new_role', p_new_role
    );

    RETURN result;
END;
$$;

-- =============================================================================
-- FUNCTION: admin_delete_user
-- Deletes a user
-- =============================================================================
CREATE OR REPLACE FUNCTION admin_delete_user(
    p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    calling_user_role text;
    target_user record;
    admin_count integer;
    result jsonb;
BEGIN
    -- Check if the calling user is an admin
    SELECT COALESCE(raw_user_meta_data->>'role', 'user')
    INTO calling_user_role
    FROM auth.users
    WHERE auth.users.id = auth.uid();

    IF calling_user_role != 'admin' THEN
        RAISE EXCEPTION 'Access denied. Admin role required.';
    END IF;

    -- Prevent self-deletion
    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot delete your own account.';
    END IF;

    -- Get the target user
    SELECT id, email, raw_user_meta_data
    INTO target_user
    FROM auth.users
    WHERE id = p_user_id;

    IF target_user.id IS NULL THEN
        RAISE EXCEPTION 'User not found.';
    END IF;

    -- If deleting an admin, check we're not removing the last admin
    IF COALESCE(target_user.raw_user_meta_data->>'role', 'user') = 'admin' THEN
        SELECT COUNT(*)
        INTO admin_count
        FROM auth.users
        WHERE raw_user_meta_data->>'role' = 'admin';

        IF admin_count <= 1 THEN
            RAISE EXCEPTION 'Cannot delete the last admin user.';
        END IF;
    END IF;

    -- Delete identities first (foreign key constraint)
    DELETE FROM auth.identities WHERE user_id = p_user_id;

    -- Delete the user
    DELETE FROM auth.users WHERE id = p_user_id;

    -- Build result
    result := jsonb_build_object(
        'success', true,
        'deleted_user_id', p_user_id,
        'deleted_email', target_user.email
    );

    RETURN result;
END;
$$;

-- =============================================================================
-- Grant execute permissions to authenticated users
-- =============================================================================
GRANT EXECUTE ON FUNCTION admin_list_users() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_create_user(text, text, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_update_user_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_user(uuid) TO authenticated;
