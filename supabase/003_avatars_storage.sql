-- =============================================================================
-- TotalKudzu - Avatars Storage Bucket Setup
-- =============================================================================
-- Run this to create the avatars bucket for profile photos
-- =============================================================================

-- Create the avatars bucket (public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,  -- Public bucket so avatars can be displayed
    5242880,  -- 5MB limit
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

-- =============================================================================
-- Storage Policies for Avatars
-- =============================================================================

-- Policy: Allow authenticated users to upload their own avatar
CREATE POLICY "Users can upload their own avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
    OR name = auth.uid()::text || '.jpg'
    OR name = auth.uid()::text || '.png'
    OR name = auth.uid()::text || '.gif'
    OR name = auth.uid()::text || '.webp'
);

-- Policy: Allow authenticated users to update their own avatar
CREATE POLICY "Users can update their own avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR name = auth.uid()::text || '.jpg'
        OR name = auth.uid()::text || '.png'
        OR name = auth.uid()::text || '.gif'
        OR name = auth.uid()::text || '.webp'
    )
);

-- Policy: Allow anyone to view avatars (public bucket)
CREATE POLICY "Anyone can view avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Policy: Allow users to delete their own avatar
CREATE POLICY "Users can delete their own avatar"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR name = auth.uid()::text || '.jpg'
        OR name = auth.uid()::text || '.png'
        OR name = auth.uid()::text || '.gif'
        OR name = auth.uid()::text || '.webp'
    )
);
