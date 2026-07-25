-- Seed data for Duty Management System

-- 1. Insert Default Organization
INSERT INTO public.organizations (id, name, code)
VALUES ('7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Duty Management System Org', 'DMSO')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- 2. Insert Departments
INSERT INTO public.departments (id, organization_id, name, code) VALUES
('b3034963-c70e-436d-8869-7c859d57a2df', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Administration', 'ADMIN'),
('4e28ee9d-ea3c-4cfb-b5a8-27e13d9a101b', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Human Resources', 'HR'),
('9df123db-9883-4903-b68e-4a6549c719e7', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Operations', 'OPS'),
('d50849c3-5fa8-4e4b-9721-aee8ef30953a', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Engineering', 'ENG')
ON CONFLICT (organization_id, code) DO UPDATE SET name = EXCLUDED.name;

-- 3. Insert Fixed Shifts according to Business Rules
-- Shift A: Reporting 08:40, Ends 16:00, Leaves 17:00 (Total 8h 20m = Normal 7h 20m + 1h OT)
-- Shift B: Reporting 16:40, Ends 00:00 (Total 7h 20m = Normal 7h 20m + 0h OT)
-- Shift C: Reporting 00:00, Ends 07:20, Leaves 09:00 (Total 9h = Normal 7h 20m + 1h 40m OT)
INSERT INTO public.shifts (id, organization_id, name, reporting_time, duty_ends, employee_leaves, normal_duty_minutes, expected_ot_minutes, is_custom) VALUES
('a59b7df8-43d9-43c2-a9b0-379e43a9b1f0', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Shift A (Morning)', '08:40:00', '16:00:00', '17:00:00', 440, 60, false),
('b59b7df8-43d9-43c2-a9b0-379e43a9b1f1', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Shift B (Evening)', '16:40:00', '00:00:00', '00:00:00', 440, 0, false),
('c59b7df8-43d9-43c2-a9b0-379e43a9b1f2', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Shift C (Night)', '00:00:00', '07:20:00', '09:00:00', 440, 100, false),
('d59b7df8-43d9-43c2-a9b0-379e43a9b1f3', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Custom Duty', '00:00:00', '00:00:00', '00:00:00', 440, 0, true)
ON CONFLICT (id) DO UPDATE SET 
    reporting_time = EXCLUDED.reporting_time, 
    duty_ends = EXCLUDED.duty_ends, 
    employee_leaves = EXCLUDED.employee_leaves,
    normal_duty_minutes = EXCLUDED.normal_duty_minutes,
    expected_ot_minutes = EXCLUDED.expected_ot_minutes,
    is_custom = EXCLUDED.is_custom;

-- 4. Insert standard Leave Categories
INSERT INTO public.leave_types (id, organization_id, name, code, is_paid, carry_forward, max_carry_forward) VALUES
('1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Casual Leave', 'CL', true, false, 0),
('2a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Earned Leave', 'EL', true, true, 30),
('3a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Half Pay Leave', 'HPL', true, true, 60),
('4a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Medical Leave', 'ML', true, true, 99),
('5a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Official Duty', 'OD', true, false, 0),
('6a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Compensatory Off', 'CO', true, true, 999),
('7a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Restricted Holiday', 'RH', true, false, 0),
('8a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Leave Without Pay', 'LWP', false, false, 0),
('9a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d', '7b12753a-c852-4a0b-9dfd-45dbfa37cfcf', 'Special Leave', 'SL', true, false, 0)
ON CONFLICT (organization_id, code) DO UPDATE SET 
    name = EXCLUDED.name,
    is_paid = EXCLUDED.is_paid,
    carry_forward = EXCLUDED.carry_forward,
    max_carry_forward = EXCLUDED.max_carry_forward;
