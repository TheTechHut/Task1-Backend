
-- Creating custom types
CREATE TYPE user_role AS ENUM ('customer', 'agent', 'admin');
CREATE TYPE ticket_status AS ENUM ('open', 'in_progress', 'resolved', 'closed', 'cancelled');
CREATE TYPE ticket_priority AS ENUM ('low', 'medium', 'high', 'urgent');

-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'customer',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tickets table
CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    agent_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    subject VARCHAR(500) NOT NULL,
    description TEXT NOT NULL,
    status ticket_status NOT NULL DEFAULT 'open',
    priority ticket_priority NOT NULL DEFAULT 'medium',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Ticket status history table for audit trail
CREATE TABLE ticket_status_history (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    status ticket_status NOT NULL,
    changed_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- Indexes for performance
CREATE INDEX idx_tickets_customer_id ON tickets(customer_id);
CREATE INDEX idx_tickets_agent_id ON tickets(agent_id);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_tickets_priority ON tickets(priority);
CREATE INDEX idx_tickets_created_at ON tickets(created_at);
CREATE INDEX idx_ticket_status_history_ticket_id ON ticket_status_history(ticket_id);
CREATE INDEX idx_ticket_status_history_changed_at ON ticket_status_history(changed_at);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for auto-updating updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tickets_updated_at
    BEFORE UPDATE ON tickets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically log status changes
CREATE OR REPLACE FUNCTION log_ticket_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if status actually changed
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO ticket_status_history (ticket_id, status, changed_by, notes)
        VALUES (NEW.id, NEW.status, NEW.agent_id, 'Status changed from ' || OLD.status || ' to ' || NEW.status);
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for automatic status logging
CREATE TRIGGER log_ticket_status_change_trigger
    AFTER UPDATE ON tickets
    FOR EACH ROW EXECUTE FUNCTION log_ticket_status_change();

-- Enable Row Level Security
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_status_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for tickets
-- Customers can only see their own tickets
CREATE POLICY ticket_customer_policy ON tickets
    FOR ALL TO authenticated_user
    USING (customer_id = current_user_id());

-- Agents can see tickets assigned to them or unassigned open tickets
CREATE POLICY ticket_agent_policy ON tickets
    FOR ALL TO authenticated_user
    USING (
        current_user_role() = 'agent' AND
        (agent_id = current_user_id() OR (agent_id IS NULL AND status = 'open'))
    );

-- Admins can see all tickets
CREATE POLICY ticket_admin_policy ON tickets
    FOR ALL TO authenticated_user
    USING (current_user_role() = 'admin');

-- RLS Policies for ticket_status_history
-- Users can see status history for tickets they have access to
CREATE POLICY ticket_history_policy ON ticket_status_history
    FOR SELECT TO authenticated_user
    USING (
        ticket_id IN (
            SELECT id FROM tickets
            WHERE customer_id = current_user_id()
            OR agent_id = current_user_id()
            OR current_user_role() = 'admin'
        )
    );

-- Helper functions for RLS (implemented based on  authentication system)
-- placeholders showing the expected function signatures
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS INTEGER AS $$
BEGIN
    -- extract user ID from session or JWT
    RETURN COALESCE(current_setting('app.current_user_id', true)::INTEGER, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION current_user_role()
RETURNS user_role AS $$
BEGIN
    -- extract user role from session or JWT
    RETURN COALESCE(current_setting('app.current_user_role', true)::user_role, 'customer');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
