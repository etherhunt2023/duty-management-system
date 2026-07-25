-- Supabase PostgreSQL Schema for Duty Management System

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. TABLES
-- ==========================================

-- Organizations Table (Multi-tenant support)
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Departments Table
CREATE TABLE IF NOT EXISTS public.departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_org_dept_code UNIQUE (organization_id, code)
);

-- Shifts Table
CREATE TABLE IF NOT EXISTS public.shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    reporting_time TIME NOT NULL,
    duty_ends TIME NOT NULL,
    employee_leaves TIME NOT NULL,
    normal_duty_minutes INT NOT NULL DEFAULT 440, -- 7 hours 20 minutes
    expected_ot_minutes INT NOT NULL DEFAULT 0,
    is_custom BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Profiles Table (Linked to auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES public.organizations(id),
    employee_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    designation TEXT NOT NULL,
    department_id UUID NOT NULL REFERENCES public.departments(id),
    mobile TEXT,
    email TEXT,
    joining_date DATE NOT NULL,
    retirement_date DATE NOT NULL,
    default_shift_id UUID REFERENCES public.shifts(id) ON DELETE SET NULL,
    reporting_officer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    photo_url TEXT,
    signature_url TEXT,
    role TEXT NOT NULL CHECK (role IN ('super_admin', 'hr', 'supervisor', 'employee', 'viewer')) DEFAULT 'employee',
    status TEXT NOT NULL CHECK (status IN ('active', 'inactive', 'suspended')) DEFAULT 'active',
    accumulated_ot_minutes INT NOT NULL DEFAULT 0, -- running OT balance in minutes
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Leave Categories / Types
CREATE TABLE IF NOT EXISTS public.leave_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    is_paid BOOLEAN NOT NULL DEFAULT TRUE,
    carry_forward BOOLEAN NOT NULL DEFAULT FALSE,
    max_carry_forward INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_org_leave_code UNIQUE (organization_id, code)
);

-- Leave Balances
CREATE TABLE IF NOT EXISTS public.leave_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    leave_type_id UUID NOT NULL REFERENCES public.leave_types(id) ON DELETE CASCADE,
    year INT NOT NULL,
    opening_balance NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    earned NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    used NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    remaining NUMERIC(5,2) GENERATED ALWAYS AS (opening_balance + earned - used) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_employee_leave_year UNIQUE (employee_id, leave_type_id, year)
);

-- Holidays Table
CREATE TABLE IF NOT EXISTS public.holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('national', 'gazetted', 'restricted', 'weekly_off')) DEFAULT 'gazetted',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_org_holiday_date UNIQUE (organization_id, date)
);

-- Attendance Table
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    shift_id UUID NOT NULL REFERENCES public.shifts(id),
    check_in TIMESTAMPTZ,
    check_out TIMESTAMPTZ,
    duty_minutes INT NOT NULL DEFAULT 0,
    ot_minutes INT NOT NULL DEFAULT 0,
    remaining_ot_minutes INT NOT NULL DEFAULT 0, -- running carry-forward of OT after this entry
    co_generated INT NOT NULL DEFAULT 0,
    entry_mode TEXT NOT NULL CHECK (entry_mode IN ('manual', 'ocr')) DEFAULT 'manual',
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_employee_attendance_date UNIQUE (employee_id, date)
);

-- Leave Applications
CREATE TABLE IF NOT EXISTS public.leave_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    leave_type_id UUID NOT NULL REFERENCES public.leave_types(id) ON DELETE CASCADE,
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    reason TEXT NOT NULL,
    attachment_url TEXT,
    medical_certificate_url TEXT,
    status TEXT NOT NULL CHECK (status IN ('pending_supervisor', 'pending_admin', 'approved', 'rejected')) DEFAULT 'pending_supervisor',
    supervisor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    supervisor_remarks TEXT,
    supervisor_approved_at TIMESTAMPTZ,
    admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    admin_remarks TEXT,
    admin_approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Compensatory Off (CO) Transaction Ledger
CREATE TABLE IF NOT EXISTS public.co_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    attendance_id UUID REFERENCES public.attendance(id) ON DELETE SET NULL,
    leave_application_id UUID REFERENCES public.leave_applications(id) ON DELETE SET NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('earned', 'used', 'expired', 'adjusted')),
    amount NUMERIC(4,2) NOT NULL, -- e.g., 1.00 for earning, -1.00 for using
    expiry_date DATE,
    is_expired BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audit Logs Table
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('leave', 'co', 'birthday', 'anniversary', 'system')),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================
-- 2. INDEXES (High scalability optimization)
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_profiles_employee_id ON public.profiles(employee_id);
CREATE INDEX IF NOT EXISTS idx_profiles_dept ON public.profiles(department_id);
CREATE INDEX IF NOT EXISTS idx_attendance_employee_date ON public.attendance(employee_id, date);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON public.attendance(date);
CREATE INDEX IF NOT EXISTS idx_leave_app_employee ON public.leave_applications(employee_id);
CREATE INDEX IF NOT EXISTS idx_leave_app_dates ON public.leave_applications(from_date, to_date);
CREATE INDEX IF NOT EXISTS idx_co_ledger_employee ON public.co_ledger(employee_id);
CREATE INDEX IF NOT EXISTS idx_co_ledger_expiry ON public.co_ledger(expiry_date) WHERE is_expired = FALSE;
CREATE INDEX IF NOT EXISTS idx_holidays_date ON public.holidays(date);

-- ==========================================
-- 3. CALCULATION FUNCTIONS & TRIGGERS
-- ==========================================

-- Function to handle shift overtime and running OT -> CO calculations
CREATE OR REPLACE FUNCTION public.process_attendance_ot_co()
RETURNS TRIGGER AS $$
DECLARE
    v_normal_duty_minutes INT := 440; -- 7h 20m default
    v_duty_minutes INT := 0;
    v_ot_minutes INT := 0;
    v_old_ot_minutes INT := 0;
    v_net_ot_change INT := 0;
    v_current_accum INT := 0;
    v_total_accum INT := 0;
    v_co_adjust INT := 0;
    v_final_accum INT := 0;
    v_expiry_date DATE;
BEGIN
    -- 1. Retrieve the configured normal duty minutes for this shift
    SELECT normal_duty_minutes INTO v_normal_duty_minutes 
    FROM public.shifts 
    WHERE id = NEW.shift_id;
    
    IF v_normal_duty_minutes IS NULL THEN
        v_normal_duty_minutes := 440;
    END IF;

    -- 2. Calculate duty minutes from check_in and check_out
    IF NEW.check_in IS NOT NULL AND NEW.check_out IS NOT NULL THEN
        v_duty_minutes := EXTRACT(EPOCH FROM (NEW.check_out - NEW.check_in)) / 60;
        IF v_duty_minutes < 0 THEN
            v_duty_minutes := 0;
        END IF;
    ELSE
        v_duty_minutes := 0;
    END IF;
    NEW.duty_minutes := v_duty_minutes;

    -- 3. Calculate daily overtime (OT = Total Duty - 07:20, never negative)
    v_ot_minutes := GREATEST(0, v_duty_minutes - v_normal_duty_minutes);
    NEW.ot_minutes := v_ot_minutes;

    -- 4. Calculate change in OT for running balance adjustments
    IF TG_OP = 'UPDATE' THEN
        v_old_ot_minutes := OLD.ot_minutes;
    ELSE
        v_old_ot_minutes := 0;
    END IF;
    v_net_ot_change := v_ot_minutes - v_old_ot_minutes;

    -- Lock the profile row to prevent race conditions in running balance
    SELECT accumulated_ot_minutes INTO v_current_accum 
    FROM public.profiles 
    WHERE id = NEW.employee_id
    FOR UPDATE;

    -- 5. Calculate new running accumulated balance
    v_total_accum := v_current_accum + v_net_ot_change;
    
    -- Handle mathematical conversion: every 440 minutes = 1 CO
    v_co_adjust := floor(v_total_accum / 440.0)::integer;
    v_final_accum := v_total_accum - (v_co_adjust * 440);

    -- 6. Apply updates to the profile's accumulated OT
    UPDATE public.profiles 
    SET accumulated_ot_minutes = v_final_accum 
    WHERE id = NEW.employee_id;

    -- Store results in the attendance record
    NEW.co_generated := GREATEST(0, v_co_adjust); -- Only count positive newly generated COs here
    NEW.remaining_ot_minutes := v_final_accum;

    -- 7. Log CO earnings in the ledger if any CO was generated
    IF v_co_adjust > 0 THEN
        v_expiry_date := (NEW.date + INTERVAL '180 days')::DATE; -- CO expires in 6 months
        INSERT INTO public.co_ledger (
            employee_id,
            attendance_id,
            transaction_type,
            amount,
            expiry_date
        ) VALUES (
            NEW.employee_id,
            NEW.id,
            'earned',
            v_co_adjust::NUMERIC(4,2),
            v_expiry_date
        );
        
        -- Insert a system notification
        INSERT INTO public.notifications (
            employee_id,
            title,
            message,
            type
        ) VALUES (
            NEW.employee_id,
            'Compensatory Off (CO) Earned',
            'You have earned ' || v_co_adjust || ' CO from your overtime work on ' || TO_CHAR(NEW.date, 'YYYY-MM-DD') || '.',
            'co'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_attendance_calculations
BEFORE INSERT OR UPDATE ON public.attendance
FOR EACH ROW
EXECUTE FUNCTION public.process_attendance_ot_co();

-- ==========================================
-- 4. LEAVE BALANCE DEBIT TRIGGER
-- ==========================================

-- Deduct leave balance when leave is approved
CREATE OR REPLACE FUNCTION public.process_leave_approval()
RETURNS TRIGGER AS $$
DECLARE
    v_leave_code TEXT;
    v_leave_days NUMERIC(5,2);
    v_year INT;
    v_co_row RECORD;
    v_needed_co NUMERIC(5,2);
    v_deducted_co NUMERIC(5,2);
BEGIN
    -- Execute only when the status changes to approved
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        
        -- 1. Get leave code details
        SELECT code INTO v_leave_code 
        FROM public.leave_types 
        WHERE id = NEW.leave_type_id;

        -- 2. Calculate leave days
        v_leave_days := (NEW.to_date - NEW.from_date) + 1;
        v_year := EXTRACT(YEAR FROM NEW.from_date)::INT;

        -- 3. Check leave balance exists and deduct
        -- For 'LWP' (Leave Without Pay), balance can go negative or is infinite, others must be validated.
        IF v_leave_code != 'LWP' THEN
            UPDATE public.leave_balances 
            SET used = used + v_leave_days
            WHERE employee_id = NEW.employee_id 
              AND leave_type_id = NEW.leave_type_id 
              AND year = v_year;
        END IF;

        -- 4. If leave is 'CO' (Compensatory Off), deduct from the ledger in FIFO order
        IF v_leave_code = 'CO' THEN
            v_needed_co := v_leave_days;
            
            -- Find unexpired, unconsumed earned COs
            FOR v_co_row IN 
                SELECT cl.id, cl.amount - COALESCE((
                    SELECT SUM(ABS(amount)) 
                    FROM public.co_ledger 
                    WHERE employee_id = NEW.employee_id 
                      AND transaction_type = 'used' 
                      AND id = cl.id -- linked to this earning
                ), 0) AS remaining_earning
                FROM public.co_ledger cl
                WHERE cl.employee_id = NEW.employee_id 
                  AND cl.transaction_type = 'earned' 
                  AND cl.is_expired = FALSE
                  AND cl.expiry_date >= CURRENT_DATE
                ORDER BY cl.created_at ASC -- FIFO
            LOOP
                EXIT WHEN v_needed_co <= 0;
                
                IF v_co_row.remaining_earning > 0 THEN
                    v_deducted_co := LEAST(v_needed_co, v_co_row.remaining_earning);
                    v_needed_co := v_needed_co - v_deducted_co;
                    
                    -- Insert debit transaction linked to this leaf
                    INSERT INTO public.co_ledger (
                        employee_id,
                        leave_application_id,
                        transaction_type,
                        amount
                    ) VALUES (
                        NEW.employee_id,
                        NEW.id,
                        'used',
                        -v_deducted_co
                    );
                END IF;
            END LOOP;
        END IF;

        -- Send Notification
        INSERT INTO public.notifications (
            employee_id,
            title,
            message,
            type
        ) VALUES (
            NEW.employee_id,
            'Leave Request Approved',
            'Your request for ' || v_leave_code || ' from ' || TO_CHAR(NEW.from_date, 'YYYY-MM-DD') || ' to ' || TO_CHAR(NEW.to_date, 'YYYY-MM-DD') || ' has been approved.',
            'leave'
        );

    ELSIF NEW.status = 'rejected' AND (OLD.status IS NULL OR OLD.status != 'rejected') THEN
        -- Send rejection notification
        INSERT INTO public.notifications (
            employee_id,
            title,
            message,
            type
        ) VALUES (
            NEW.employee_id,
            'Leave Request Rejected',
            'Your request for leave from ' || TO_CHAR(NEW.from_date, 'YYYY-MM-DD') || ' to ' || TO_CHAR(NEW.to_date, 'YYYY-MM-DD') || ' has been rejected.',
            'leave'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_leave_approval
AFTER UPDATE ON public.leave_applications
FOR EACH ROW
EXECUTE FUNCTION public.process_leave_approval();

-- ==========================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.co_ledger ENABLE ROW LEVEL SECURITY;

-- Helper to check user role from public.profiles
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- Profiles Policies
CREATE POLICY "Super Admins & HR can manage all profiles" ON public.profiles
    FOR ALL USING (public.get_user_role() IN ('super_admin', 'hr'));

CREATE POLICY "Supervisors can view profiles" ON public.profiles
    FOR SELECT USING (public.get_user_role() = 'supervisor');

CREATE POLICY "Employees can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

-- Attendance Policies
CREATE POLICY "Super Admins, HR & Supervisors can manage all attendance" ON public.attendance
    FOR ALL USING (public.get_user_role() IN ('super_admin', 'hr', 'supervisor'));

CREATE POLICY "Employees can view own attendance" ON public.attendance
    FOR SELECT USING (auth.uid() = employee_id);

CREATE POLICY "Employees can insert own attendance (Offline uploads)" ON public.attendance
    FOR INSERT WITH CHECK (auth.uid() = employee_id);

-- Leave Applications Policies
CREATE POLICY "Super Admins & HR can manage all leave apps" ON public.leave_applications
    FOR ALL USING (public.get_user_role() IN ('super_admin', 'hr'));

CREATE POLICY "Supervisors can view and update leave applications" ON public.leave_applications
    FOR ALL USING (public.get_user_role() = 'supervisor');

CREATE POLICY "Employees can manage own leave applications" ON public.leave_applications
    FOR ALL USING (auth.uid() = employee_id);

-- ==========================================
-- 6. AUTOMATED PROFILE SYNCRONIZATION TRIGGER
-- ==========================================

-- Trigger to create a public profile when a new user signs up in auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_org_id UUID;
    v_dept_id UUID;
BEGIN
    -- Fallback/Initial default tenant configuration
    SELECT id INTO v_org_id FROM public.organizations LIMIT 1;
    IF v_org_id IS NULL THEN
        -- Auto seed default organization
        INSERT INTO public.organizations (name, code)
        VALUES ('Default Org', 'DFT')
        RETURNING id INTO v_org_id;
    END IF;

    SELECT id INTO v_dept_id FROM public.departments WHERE organization_id = v_org_id LIMIT 1;
    IF v_dept_id IS NULL THEN
        -- Auto seed default department
        INSERT INTO public.departments (organization_id, name, code)
        VALUES (v_org_id, 'Administration', 'ADMIN')
        RETURNING id INTO v_dept_id;
    END IF;

    INSERT INTO public.profiles (
        id,
        organization_id,
        employee_id,
        name,
        designation,
        department_id,
        joining_date,
        retirement_date,
        role,
        status,
        email
    ) VALUES (
        NEW.id,
        v_org_id,
        'EMP-' || COALESCE(NEW.raw_user_meta_data->>'employee_id', SUBSTRING(NEW.id::TEXT FROM 1 FOR 8)),
        COALESCE(NEW.raw_user_meta_data->>'name', 'New Employee'),
        COALESCE(NEW.raw_user_meta_data->>'designation', 'Staff'),
        v_dept_id,
        CURRENT_DATE,
        (CURRENT_DATE + INTERVAL '30 years')::DATE,
        COALESCE(NEW.raw_user_meta_data->>'role', 'employee'),
        'active',
        NEW.email
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trigger_sync_user_signup
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();
