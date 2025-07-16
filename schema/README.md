
---

# Ticketing System Database Schema

##  Overview

This document outlines the PostgreSQL database schema design for a secure and scalable ticketing system. The system enables customers to submit tickets, support agents to manage and resolve them, and includes features such as audit trails, row-level security (RLS), and role-based access control.

---

## Schema Design Rationale

###  Entity Design Choices

#### 1. **Users Table**

* A unified `users` table is used for all roles (`customer`, `agent`, `admin`) with a `role` ENUM.
* **Why**: Simplifies design, reduces redundancy, and allows seamless role changes without needing data migration.
* **Trade-off**: May introduce slight storage overhead for role-specific fields not used by all users.

#### 2. **Tickets Table**

* Serves as the core entity capturing all essential ticket details.
* `agent_id` is nullable to allow unassigned tickets at creation.
* `status` and `priority` fields are implemented using ENUMs to enforce valid values.
* The table remains fully normalized; historical changes are tracked separately in `ticket_status_history`.

#### 3. **Ticket Status History Table**

* Maintains a complete audit trail of all ticket status changes.
* Uses a separate table to separate current state from historical logs.
* Includes a `notes` field for contextual information on each status change.

---


###  Data Types & Constraints

* **IDs**: Use `SERIAL` for auto-incrementing primary keys.
* **Text Fields**: Reasonable `VARCHAR` limits (e.g., 255 for names, 500 for subjects); `TEXT` for longer descriptions.
* **Timestamps**: All datetime fields use `TIMESTAMP WITH TIME ZONE` to support global time tracking.

---

## Row-Level Security (RLS)

### ️ Security Policies

####  Customers

```sql
CREATE POLICY ticket_customer_policy ON tickets
  FOR ALL TO authenticated_user
  USING (customer_id = current_user_id());
```

####  Agents

```sql
CREATE POLICY ticket_agent_policy ON tickets
  FOR ALL TO authenticated_user
  USING (
    current_user_role() = 'agent' AND
    (agent_id = current_user_id() OR (agent_id IS NULL AND status = 'open'))
  );
```

####  Admins

```sql
CREATE POLICY ticket_admin_policy ON tickets
  FOR ALL TO authenticated_user
  USING (current_user_role() = 'admin');
```

###  RLS Helper Functions

These PostgreSQL functions enable RLS by integrating with your app’s authentication system:

* `current_user_id()` → Returns the current user’s ID from session context.
* `current_user_role()` → Returns the current user's role (ENUM).
* Integration depends on your authentication mechanism (e.g., session, JWT).

---

## ️ Audit Trail Implementation

###  Automatic Logging

* A trigger captures and logs all status changes to `ticket_status_history`.
* Captures `changed_by`, timestamp, and a `notes` field for context.
* Ensures consistent, append-only logs for compliance and debugging.

###  Audit Trail Features

* `created_at` and `updated_at` fields are included on all major tables.
* Status changes are attributed to specific users.
* History table is append-only, ensuring immutability.

---

## ️ Scalability Considerations

###  Indexing Strategy

```sql
CREATE INDEX idx_tickets_customer_id ON tickets(customer_id);
CREATE INDEX idx_tickets_agent_id ON tickets(agent_id);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_tickets_priority ON tickets(priority);
CREATE INDEX idx_tickets_created_at ON tickets(created_at);
```

###  Performance Optimizations

* **Compound indexes**: Can be added for frequent multi-column queries.
* **Partial indexes**: Useful for specific status conditions (e.g., open tickets).
* **Partitioning**: Consider partitioning by time for high-volume workloads.

###  Schema Efficiency

* Foreign keys include `CASCADE` and `SET NULL` behaviors to maintain integrity.
* ENUMs reduce storage and speed up comparisons.
* Chosen data types minimize overhead while supporting flexibility.

---

##  Security Highlights

### User Protection

* Passwords are stored in **hashed** format (never plain text).
* RLS ensures strict **data isolation** between tenants.
* Audit logging supports traceability and regulatory compliance.

###  Role-Based Access Control

* Role-specific logic for **customers**, **agents**, and **admins**.
* Agents are limited to only their assigned or open tickets.
* Customers see only their own tickets.

---

##  Implementation Notes

###  Database Setup

1. Run the schema file in order (types → tables → indexes → triggers).
2. Integrate the RLS helper functions with your authentication system.
3. Enable connection pooling for scalability.
4. Monitor and tune query performance regularly.

###  Application Integration

* Ensure the app sets `current_user_id` and `current_user_role` correctly (via `SET LOCAL` or session context).
* Implement graceful error handling for RLS access violations.
* Use session-aware DB connections to enforce RLS rules consistently.

---
