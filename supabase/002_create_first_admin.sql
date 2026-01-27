-- =============================================================================
-- TotalKudzu - Create First Admin User
-- =============================================================================
-- Run this AFTER 001_user_management.sql
--
-- IMPORTANT: Replace the values below with your actual admin details
-- =============================================================================

-- Option 1: Create admin via Supabase Dashboard
-- ---------------------------------------------
-- 1. Go to Authentication > Users in your Supabase dashboard
-- 2. Click "Add user" and create a user with email/password
-- 3. Then run this SQL to set them as admin:

-- UPDATE auth.users
-- SET raw_user_meta_data = raw_user_meta_data || '{"role": "admin"}'::jsonb
-- WHERE email = 'your-admin-email@example.com';


-- Option 2: Create admin directly via SQL
-- ---------------------------------------
-- Uncomment and modify the block below:

/*
DO $$
DECLARE
    new_user_id uuid := gen_random_uuid();
    admin_email text := 'admin@example.com';  -- CHANGE THIS
    admin_password text := 'your-secure-password';  -- CHANGE THIS
    admin_display_name text := 'Admin User';  -- CHANGE THIS
BEGIN
    -- Insert the admin user
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
        admin_email,
        crypt(admin_password, gen_salt('bf')),
        NOW(),  -- Email confirmed immediately
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        jsonb_build_object(
            'role', 'admin',
            'display_name', admin_display_name
        ),
        'authenticated',
        'authenticated',
        NOW(),
        NOW(),
        '',
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
        jsonb_build_object('sub', new_user_id::text, 'email', admin_email),
        'email',
        new_user_id::text,
        NOW(),
        NOW(),
        NOW()
    );

    RAISE NOTICE 'Admin user created successfully: %', admin_email;
END $$;
*/

-- =============================================================================
-- Verify admin user exists
-- =============================================================================
-- Run this to check your admin users:

SELECT
    id,
    email,
    raw_user_meta_data->>'role' as role,
    raw_user_meta_data->>'display_name' as display_name,
    email_confirmed_at IS NOT NULL as is_verified,
    created_at
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'admin';
