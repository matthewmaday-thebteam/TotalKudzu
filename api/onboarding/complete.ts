import { createClient } from '@supabase/supabase-js';

// Vercel serverless function types (inline to avoid dependency)
interface VercelRequest {
  method?: string;
  headers: Record<string, string | string[] | undefined>;
  body: unknown;
}

interface VercelResponse {
  status: (code: number) => VercelResponse;
  json: (data: unknown) => void;
}

// Zod-like validation (inline to avoid build complexity)
interface OnboardingInput {
  company_name: string;
  hq_office_name: string;
  hq_office_timezone: string;
  hq_office_country_code: string;
  plan_tier: 'starter_10' | 'unlimited';
}

interface ValidationError {
  field: string;
  message: string;
}

function validateInput(body: unknown): { data: OnboardingInput | null; errors: ValidationError[] } {
  const errors: ValidationError[] = [];

  if (!body || typeof body !== 'object') {
    return { data: null, errors: [{ field: 'body', message: 'Request body is required' }] };
  }

  const input = body as Record<string, unknown>;

  // company_name
  if (typeof input.company_name !== 'string' || input.company_name.trim().length < 2) {
    errors.push({ field: 'company_name', message: 'Company name must be at least 2 characters' });
  } else if (input.company_name.trim().length > 100) {
    errors.push({ field: 'company_name', message: 'Company name must be under 100 characters' });
  }

  // hq_office_name
  if (typeof input.hq_office_name !== 'string' || input.hq_office_name.trim().length < 2) {
    errors.push({ field: 'hq_office_name', message: 'Office name must be at least 2 characters' });
  } else if (input.hq_office_name.trim().length > 100) {
    errors.push({ field: 'hq_office_name', message: 'Office name must be under 100 characters' });
  }

  // hq_office_timezone - validate it's a valid IANA timezone
  if (typeof input.hq_office_timezone !== 'string') {
    errors.push({ field: 'hq_office_timezone', message: 'Timezone is required' });
  } else {
    try {
      Intl.DateTimeFormat(undefined, { timeZone: input.hq_office_timezone });
    } catch {
      errors.push({ field: 'hq_office_timezone', message: 'Invalid timezone' });
    }
  }

  // hq_office_country_code
  if (typeof input.hq_office_country_code !== 'string' || input.hq_office_country_code.length !== 2) {
    errors.push({ field: 'hq_office_country_code', message: 'Country code must be 2 characters' });
  }

  // plan_tier
  if (input.plan_tier !== 'starter_10' && input.plan_tier !== 'unlimited') {
    errors.push({ field: 'plan_tier', message: 'Plan must be starter_10 or unlimited' });
  }

  if (errors.length > 0) {
    return { data: null, errors };
  }

  return {
    data: {
      company_name: (input.company_name as string).trim(),
      hq_office_name: (input.hq_office_name as string).trim(),
      hq_office_timezone: input.hq_office_timezone as string,
      hq_office_country_code: (input.hq_office_country_code as string).toUpperCase(),
      plan_tier: input.plan_tier as 'starter_10' | 'unlimited',
    },
    errors: [],
  };
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: { code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed' } });
  }

  // Extract JWT from Authorization header
  const authHeaderRaw = req.headers.authorization;
  const authHeader = Array.isArray(authHeaderRaw) ? authHeaderRaw[0] : authHeaderRaw;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: { code: 'AUTH_ERROR', message: 'Missing authorization header' } });
  }
  const jwt = authHeader.split(' ')[1];

  // Get environment variables (server-side only)
  const supabaseUrl = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL;
  const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_KEY;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
    console.error('Missing Supabase environment variables');
    return res.status(500).json({ success: false, error: { code: 'CONFIG_ERROR', message: 'Server configuration error' } });
  }

  // Create anon client to validate JWT and get user
  const anonClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });

  const { data: { user }, error: authError } = await anonClient.auth.getUser();
  if (authError || !user) {
    return res.status(401).json({ success: false, error: { code: 'AUTH_ERROR', message: 'Invalid or expired token' } });
  }

  // Validate input
  const { data: input, errors: validationErrors } = validateInput(req.body);
  if (!input) {
    return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Invalid input', details: validationErrors } });
  }

  // Create service role client for privileged operations
  const serviceClient = createClient(supabaseUrl, supabaseServiceKey);

  // Check idempotency - if user already has a membership, return existing data
  const { data: existingMember } = await serviceClient
    .from('company_member')
    .select('id, company_id, company:company_id(id, name)')
    .eq('user_id', user.id)
    .is('deleted_at', null)
    .single();

  if (existingMember) {
    // User already onboarded - fetch billing info and return
    const { data: existingBilling } = await serviceClient
      .from('company_billing')
      .select('*')
      .eq('company_id', existingMember.company_id)
      .single();

    // Get office info
    const { data: existingOffice } = await serviceClient
      .from('office')
      .select('id')
      .eq('company_id', existingMember.company_id)
      .is('deleted_at', null)
      .limit(1)
      .single();

    return res.status(200).json({
      success: true,
      data: {
        company_id: existingMember.company_id,
        hq_office_id: existingOffice?.id || null,
        member_id: existingMember.id,
        billing_status: existingBilling?.billing_status || 'trialing',
        trial_started_at: existingBilling?.trial_started_at || new Date().toISOString(),
        trial_ends_at: existingBilling?.trial_ends_at || new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
        plan_tier: existingBilling?.plan_tier || input.plan_tier,
      },
      idempotent: true,
    });
  }

  // Begin transaction - create all entities
  try {
    // 1. Create company
    const { data: company, error: companyError } = await serviceClient
      .from('company')
      .insert({ name: input.company_name })
      .select('id')
      .single();

    if (companyError || !company) {
      console.error('Failed to create company:', companyError);
      return res.status(500).json({
        success: false,
        error: {
          code: 'DATABASE_ERROR',
          message: 'Failed to create company',
          details: companyError?.message || 'Unknown error',
        },
      });
    }

    // 2. Create HQ office
    const { data: office, error: officeError } = await serviceClient
      .from('office')
      .insert({
        company_id: company.id,
        name: input.hq_office_name,
        timezone: input.hq_office_timezone,
        country_code: input.hq_office_country_code,
      })
      .select('id')
      .single();

    if (officeError || !office) {
      console.error('Failed to create office:', officeError);
      // Attempt cleanup
      await serviceClient.from('company').delete().eq('id', company.id);
      throw new Error('Failed to create office');
    }

    // 3. Create admin member with primary_office_id = NULL
    // (Trigger requires member_office to exist before setting primary_office_id)
    const { data: member, error: memberError } = await serviceClient
      .from('company_member')
      .insert({
        company_id: company.id,
        user_id: user.id,
        role: 'admin',
        status: 'active',
        primary_office_id: null,
      })
      .select('id')
      .single();

    if (memberError || !member) {
      console.error('Failed to create member:', memberError);
      // Attempt cleanup
      await serviceClient.from('office').delete().eq('id', office.id);
      await serviceClient.from('company').delete().eq('id', company.id);
      throw new Error('Failed to create member');
    }

    // 4. Link member to office with is_primary = true
    // Trigger will automatically set company_member.primary_office_id
    const { error: memberOfficeError } = await serviceClient
      .from('member_office')
      .insert({
        member_id: member.id,
        office_id: office.id,
        is_primary: true,
      });

    if (memberOfficeError) {
      console.error('Failed to create member_office:', memberOfficeError);
      // Attempt cleanup
      await serviceClient.from('company_member').delete().eq('id', member.id);
      await serviceClient.from('office').delete().eq('id', office.id);
      await serviceClient.from('company').delete().eq('id', company.id);
      throw new Error('Failed to link member to office');
    }

    // 5. Create Headquarters department
    const { data: department, error: deptError } = await serviceClient
      .from('department')
      .insert({
        company_id: company.id,
        name: 'Headquarters',
      })
      .select('id')
      .single();

    if (deptError || !department) {
      console.error('Failed to create department:', deptError);
      // Attempt cleanup
      await serviceClient.from('member_office').delete().eq('member_id', member.id);
      await serviceClient.from('company_member').delete().eq('id', member.id);
      await serviceClient.from('office').delete().eq('id', office.id);
      await serviceClient.from('company').delete().eq('id', company.id);
      throw new Error('Failed to create department');
    }

    // 6. Link member to department with is_primary = true
    const { error: memberDeptError } = await serviceClient
      .from('member_department')
      .insert({
        member_id: member.id,
        department_id: department.id,
        is_primary: true,
      });

    if (memberDeptError) {
      console.error('Failed to create member_department:', memberDeptError);
      // Attempt cleanup
      await serviceClient.from('department').delete().eq('id', department.id);
      await serviceClient.from('member_office').delete().eq('member_id', member.id);
      await serviceClient.from('company_member').delete().eq('id', member.id);
      await serviceClient.from('office').delete().eq('id', office.id);
      await serviceClient.from('company').delete().eq('id', company.id);
      throw new Error('Failed to link member to department');
    }

    // 7. Create billing record
    const trialStartedAt = new Date();
    const trialEndsAt = new Date(trialStartedAt.getTime() + 7 * 24 * 60 * 60 * 1000);

    const { error: billingError } = await serviceClient
      .from('company_billing')
      .insert({
        company_id: company.id,
        plan_tier: input.plan_tier,
        billing_status: 'trialing',
        billing_provider: 'simulated',
        trial_started_at: trialStartedAt.toISOString(),
        trial_ends_at: trialEndsAt.toISOString(),
        max_users: input.plan_tier === 'starter_10' ? 10 : null,
      });

    if (billingError) {
      console.error('Failed to create billing:', billingError);
      // Attempt cleanup
      await serviceClient.from('member_department').delete().eq('member_id', member.id);
      await serviceClient.from('department').delete().eq('id', department.id);
      await serviceClient.from('member_office').delete().eq('member_id', member.id);
      await serviceClient.from('company_member').delete().eq('id', member.id);
      await serviceClient.from('office').delete().eq('id', office.id);
      await serviceClient.from('company').delete().eq('id', company.id);
      throw new Error('Failed to create billing record');
    }

    // Success!
    return res.status(201).json({
      success: true,
      data: {
        company_id: company.id,
        hq_office_id: office.id,
        member_id: member.id,
        billing_status: 'trialing',
        trial_started_at: trialStartedAt.toISOString(),
        trial_ends_at: trialEndsAt.toISOString(),
        plan_tier: input.plan_tier,
      },
    });
  } catch (error) {
    console.error('Onboarding failed:', error);
    return res.status(500).json({
      success: false,
      error: {
        code: 'DATABASE_ERROR',
        message: error instanceof Error ? error.message : 'Failed to complete onboarding',
      },
    });
  }
}
