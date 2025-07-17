-- ticketing_schema.sql
-- PostgreSQL database schema for secure ticketing system
-- Includes tables, RLS policies, audit trails, and indexes as per requirements

-- Create ENUM for user roles (as specified in requirements)
CREATE TYPE user_role AS ENUM ('customer', 'agent', 'admin');

-- Users table (exact fields from requirements)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    hashed_password TEXT NOT NULL,
    role user_role NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Tickets table (exact fields from requirements)
CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    agent_id UUID REFERENCES users(id) ON DELETE SET NULL,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' 
        CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    priority TEXT 
        CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- TicketStatusHistory table (exact fields from requirements)
CREATE TABLE ticket_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    status TEXT NOT NULL 
        CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    changed_by UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for performance (as specified)
CREATE INDEX idx_tickets_customer_id ON tickets(customer_id);
CREATE INDEX idx_tickets_agent_id ON tickets(agent_id);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_status_history_ticket_id ON ticket_status_history(ticket_id);

-- Enable Row-Level Security on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_status_history ENABLE ROW LEVEL SECURITY;

-- Create helper functions for RLS
CREATE OR REPLACE FUNCTION current_user_id() 
RETURNS UUID AS $$
BEGIN
    RETURN current_setting('app.current_user_id')::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION current_user_role() 
RETURNS TEXT AS $$
BEGIN
    RETURN current_setting('app.current_user_role');
EXCEPTION WHEN OTHERS THEN
    RETURN 'customer';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies (exactly matching requirements)

-- Users can only see themselves (unless admin)
CREATE POLICY user_select_policy ON users
    FOR SELECT USING (
        id = current_user_id() OR 
        current_user_role() = 'admin'
    );

-- Customers can only see their own tickets
CREATE POLICY customer_ticket_policy ON tickets
    FOR SELECT USING (
        customer_id = current_user_id()
    );

-- Agents can see tickets assigned to them or open tickets
CREATE POLICY agent_ticket_policy ON tickets
    FOR SELECT USING (
        current_user_role() = 'agent' AND 
        (agent_id = current_user_id() OR status = 'open')
    );

-- Admins can see all tickets
CREATE POLICY admin_ticket_policy ON tickets
    FOR SELECT USING (
        current_user_role() = 'admin'
    );

-- Status history follows ticket visibility rules
CREATE POLICY status_history_policy ON ticket_status_history
    FOR SELECT USING (
        ticket_id IN (
            SELECT id FROM tickets WHERE
            customer_id = current_user_id() OR
            agent_id = current_user_id() OR
            current_user_role() = 'admin'
        )
    );

-- Create triggers for automatic status history (audit trail)
CREATE OR REPLACE FUNCTION record_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status <> OLD.status THEN
        INSERT INTO ticket_status_history 
        (ticket_id, status, changed_by)
        VALUES (NEW.id, NEW.status, current_user_id());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ticket_status_change_trigger
AFTER UPDATE ON tickets
FOR EACH ROW EXECUTE FUNCTION record_status_change();

-- Create timestamp update trigger
CREATE OR REPLACE FUNCTION update_timestamps()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_timestamp
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_timestamps();

CREATE TRIGGER update_ticket_timestamp
BEFORE UPDATE ON tickets
FOR EACH ROW EXECUTE FUNCTION update_timestamps();

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

