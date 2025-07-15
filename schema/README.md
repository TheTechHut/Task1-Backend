# Ticketing System Database Schema

**Created:** July 15, 2025  
**Author:** Alvin Ondieki   

---

##  Overview

This schema defines a secure, scalable, and auditable **ticketing system backend** for PostgreSQL. The system allows:

- Customers to create support tickets
- Agents to manage and resolve tickets
- Admins to oversee all activity
- Automatic fully tracking of ticket status changes
- Enforcement of Row-Level Security (RLS)

---

##  Design Summary

### 1. **Entities and Structure**

#### Entities
- users : Stores all system users with roles-customer, agent, and admin accounts
- tickets: Main table for support tickets
- ticket_status_history: Tracks each change in ticket status for audit

#### Key Fields
- UUIDs used as primary keys for scalability and security
- user_role, ticket_status, ticket_priority implemented as PostgreSQL ENUMs

- All tables include timestamp fields (created_at, updated_at) for auditability.

---

### 2. **Design Rationale**

#### Roles: ENUM vs Separate Table
Roles are stored using ENUM (user_role) for fast validation and simple comparison, avoiding unnecessary joins.

#### Normalization
Data is fully normalized (3NF):
- Repetitive values like status, priority, and role use ENUMs
- All relationships use foreign keys

#### Trade-Offs:
- Using ENUMs makes adding new values harder without a migration
- Fully normalized design ensures data integrity but can require more joins

---

### 3. **Security – Row-Level Security (RLS)**

RLS is enabled on both tickets and ticket_status_history. Here's how it would be applied:

#### Customers:
- Can SELECT only their own tickets (customer_id = current_user)
- Can INSERT their own tickets

#### Agents:
- Can SELECT tickets assigned to them or with status = open and no agent
- Can UPDATE tickets assigned to them

#### Admins:
- Have unrestricted access (USING (true))

 Access control is implemented using current_setting(app.user_id) and app.role.

---

### 4. **Auditability**

- ticket_status_history is an **immutable audit table**
- Tracks:
  - Status changes
  - Who changed it (changed_by)
  - When (changed_at)
- No update triggers: changes are append-only

---

### 5. **Performance Considerations**
Indexed columns:
- customer_id, agent_id, status, priority in tickets
- ticket_id, changed_at in ticket_status_history

This supports:
- Fast filtering in dashboards
- Historical queries on status changes

---

## Open Questions
- Should agents be allowed to reassign tickets to others?
- Should email notifications or activity logs be included in future design?

---

