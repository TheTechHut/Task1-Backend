# Ticketing System Database Schema

This project contains the PostgreSQL database schema design for a secure and scalable ticketing system backend.

---

##  Overview

The system supports:
- Customers submitting support tickets
- Support agents managing and resolving tickets
- Admins overseeing activity
- Full tracking of ticket status changes (audit trail)
- Row-level security (RLS) for multi-tenant access

---

##  Entity-Relationship Diagram (ERD)

See [`ticketing_erd.png`](./ticketing_erd.png) for the full ERD.

It contains:
- `users` table
- `tickets` table
- `ticket_status_history` table

---

##  Schema Design Rationale

### Normalization
- The schema is **fully normalized** to avoid data duplication and improve maintainability.
- `ticket_status_history` is separated from `tickets` to track status changes independently.

### Simplicity
- Uses UUIDs as primary keys for better scalability in distributed systems.
- Uses `CHECK` constraints instead of separate lookup tables for roles, status, and priority to reduce join complexity.

---

##  Row-Level Security (RLS) Readiness

This schema is designed to work with PostgreSQL's RLS features:
- **Customers** can only access their own tickets.
- **Agents** can only access tickets that are either **open** or **assigned to them**.
- **Admins** can access everything.

Custom PostgreSQL RLS policies would be defined during implementation (not in this schema).

---

##  Auditability

- The `ticket_status_history` table acts as an **audit trail**.
- It stores:
  - The **ticket ID**
  - The **status**
  - **Who** made the change (`changed_by`)
  - **When** the change occurred (`changed_at`)

This helps track the full lifecycle of every ticket.

---

## 🚀 Scalability & Performance

- Uses **UUIDs** for scalability across distributed systems.
- Indexes created on:
  - `customer_id`
  - `agent_id`
  - `status`

These indexes optimize common queries like:
```sql
SELECT * FROM tickets WHERE agent_id = ?;
SELECT * FROM tickets WHERE customer_id = ?;
