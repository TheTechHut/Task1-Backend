# 🎫 Ticketing System Backend – Database Schema

This project defines the PostgreSQL schema and design rationale for a secure and scalable ticketing system backend using Django and Railway-hosted PostgreSQL.

---

## 📐 ERD Diagram

![ERD](./erd.png)  
> *(Attach and rename your ERD image as `erd.png` in the schema folder)*

---

## 🧱 Database Design Overview

### 📌 Entities
- **User**: Inherits from Django’s `AbstractUser`. Includes a `role` field (enum: `customer`, `agent`, `admin`).
- **Ticket**: Represents customer-submitted support tickets.
- **TicketStatusHistory**: Audit trail of status changes for each ticket.

### 🧩 Relationships
- One user (customer) can create many tickets.
- One ticket may be assigned to one agent.
- Each ticket can have multiple status changes over time.

---

## 🔐 Row-Level Security (RLS)

To ensure **multi-tenant security**:

- RLS is enabled on the `tickets_ticket` table.
- A PostgreSQL policy restricts customers to only view **their own tickets**.
- Agents can only access **assigned or unassigned (open) tickets**.

Example RLS policy for customers:

```sql
CREATE POLICY customer_tickets_policy
ON tickets_ticket
FOR SELECT
USING (customer_id = current_setting('myapp.current_user_id')::int);
