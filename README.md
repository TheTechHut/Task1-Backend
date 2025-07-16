# Ticketing System Database Schema

## Rationale for Design Choices
The schema is **fully normalized** to reduce redundancy, enforce data integrity, and simplify updates across the system. It separates users, tickets, and ticket status history into distinct tables, each serving a specific purpose:
- The **`users`** table captures essential information about customers, agents, and admins, with roles defined as an ENUM for simplicity.
- The **`tickets`** table links tickets to customers and optionally to agents, keeping the original ticket data concise.
- The **`ticket_status_history`** table maintains a historical log of all status changes, enabling tracing without cluttering the tickets table.

Using ENUMs for roles, status, and priority avoids additional joins while ensuring consistent values. The design is optimized for data integrity, ease of maintenance, and security readiness.

## Trade-offs for Scalability, Simplicity, and Security
- **Scalability:** Normalization supports growth by reducing data duplication. Indexing on foreign keys like `customer_id`, `agent_id`, and `status` ensures efficient queries as data volume increases.
- **Simplicity:** ENUMs simplify implementation by avoiding extra lookup tables for roles, statuses, and priorities. However, this makes it less flexible if these categories need frequent changes.
- **Security:** Foreign keys and strict relationships ensure referential integrity. The schema is structured to support **Row-Level Security (RLS)**, which restricts data access based on user roles and relationships.

## Support for Row-Level Security and Audit Trails
### Row-Level Security
The schema enables RLS policies to control data visibility:
- **Customers** can only access tickets where `customer_id` matches their user ID.
- **Agents** can access tickets assigned to them or opened tickets.
- **Admins** have unrestricted access.

RLS can be enforced using PostgreSQL's `CREATE POLICY` and `ENABLE ROW LEVEL SECURITY` features on the `tickets` and `ticket_status_history` tables.

### Audit Trails
The **`ticket_status_history`** table ensures a robust audit trail:
- Records every status change on a ticket.
- Tracks the user responsible (`changed_by`) and the timestamp (`changed_at`).
- Enables reconstruction of the entire lifecycle of any ticket for auditing purposes.

Timestamps (`created_at`, `updated_at`) in all tables further support change tracking across the system.
