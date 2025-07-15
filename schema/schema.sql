-- ============================================================================
-- Ticketting System Database Schema
-- Databasse: POSTGREESQL DATABASE
-- Description: This schema defines the structure for a ticketting system
-- Author: Alvin Ondieki
-- Date: July 15, 2025
-- ============================================================================

-- ============================================================================
-- 1. ENUM Typess
-- ============================================================================
CREATE TYPE user_role AS ENUM ('customer', 'agent', 'admin');
CREATE TYPE ticket_status AS ENUM ('open', 'in_progress', 'resolved', 'closed');
CREATE TYPE ticket_priority AS ENUM ('low', 'medium', 'high', 'urgent');

-- ============================================================================
-- 2. Timestamps Trigger Function to auto-update
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_set_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ============================================================================
-- 3. Users Table
-- ============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    email VARCHAR UNIQUE NOT NULL,
    hashed_password TEXT NOT NULL,
    role user_role NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto Update the updated_at field on user updates
CREATE TRIGGER trg_users_set_timestamp
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION trg_set_timestamp();

-- ============================================================================
-- 4. Tickets Table
-- ============================================================================
CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    agent_id UUID REFERENCES users(id) ON DELETE SET NULL,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status ticket_status NOT NULL DEFAULT 'open',
    priority ticket_priority NOT NULL DEFAULT 'medium',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto Update the updated_at field on ticket updates
CREATE TRIGGER trg_tickets_set_timestamp
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION trg_set_timestamp();

-- ============================================================================
-- 5. Ticket Status History Table
-- ============================================================================
CREATE TABLE ticket_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    status ticket_status NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 6. Indexes for Performance
-- ============================================================================
CREATE INDEX idx_tickets_customer ON tickets(customer_id);
CREATE INDEX idx_tickets_agent ON tickets(agent_id);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_tickets_priority ON tickets(priority);
CREATE INDEX idx_status_history_ticket_time ON ticket_status_history(ticket_id, changed_at DESC);

-- ============================================================================
-- 7. Row-Level Security (RLS)
-- ============================================================================
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_status_history ENABLE ROW LEVEL SECURITY;

-- -----------------------------
-- Tickets RLS Policies
-- -----------------------------

-- Customers can view only their own tickets
CREATE POLICY tickets_select_customer ON tickets
FOR SELECT
USING (
    current_setting('app.role', true) = 'customer'
    AND customer_id = current_setting('app.user_id')::uuid
);

-- Agents can view tickets assigned tothem or unassigned open tickets
CREATE POLICY tickets_select_agent ON tickets
FOR SELECT
USING (
    current_setting('app.role', true) = 'agent'
    AND (
        agent_id = current_setting('app.user_id')::uuid
        OR (agent_id IS NULL AND status = 'open')
    )
);

-- Admins unrestricted access to te systen
CREATE POLICY tickets_admin_all ON tickets
FOR ALL
USING (
    current_setting('app.role', true) = 'admin'
);

-- Customers can insert their own tickets
CREATE POLICY tickets_insert_customer ON tickets
FOR INSERT
WITH CHECK (
    current_setting('app.role', true) = 'customer'
    AND customer_id = current_setting('app.user_id')::uuid
);

-- Agents can update tickets assigned to them
CREATE POLICY tickets_update_agent ON tickets
FOR UPDATE
USING (
    current_setting('app.role', true) = 'agent'
    AND agent_id = current_setting('app.user_id')::uuid
);

-- -----------------------------
-- Ticket Status History withh RLS Policies
-- -----------------------------

-- Anyone can view history if they can view thee ticketss and inherits ticket RLS
CREATE POLICY history_select ON ticket_status_history
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM tickets t
        WHERE t.id = ticket_status_history.ticket_id
    )
);

-- Anyone who can updatea ticket can insert a status change row
CREATE POLICY history_insert ON ticket_status_history
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM tickets t
        WHERE t.id = ticket_status_history.ticket_id
    )
);

-- ============================================================================
-- 8. View for dataa nalytocs and reporting
-- ============================================================================
CREATE VIEW v_ticket_overview AS
SELECT t.*, c.name AS customer_name, a.name AS agent_name
FROM tickets t
JOIN users c ON c.id = t.customer_id
LEFT JOIN users a ON a.id = t.agent_id;
