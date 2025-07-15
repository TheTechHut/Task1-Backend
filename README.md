
# PostgreSQL Ticketing System Database

## Overview

I've designed a secure, auditable ticketing system database with:

- **User roles**: Customers, Agents, and Admins
- **Ticket lifecycle tracking**: From creation to resolution
- **Row-Level Security (RLS)**: Strict data access controls
- **Full audit trails**: Every status change is recorded

## Schema Features

### Core Tables

1. **Users**

   - Stores all user accounts with hashed passwords
   - Role-based permissions (customer/agent/admin)
2. **Tickets**

   - Tracks all ticket details and current status
   - Relationships to customers and assigned agents
3. **TicketStatusHistory**

   - Complete audit trail of all status changes
   - Tracks who made changes and when

### Security Implementation

- **Password security**: All passwords are stored hashed
- **Row-Level Security Policies**:
  ```sql
  -- Customers only see their tickets
  CREATE POLICY customer_policy ON tickets
    FOR SELECT USING (customer_id = current_user_id());
  ```

## Design Rationale

### Normalization Decisions

- **Normalized Tables**:
  - Separate `ticket_status_history` for auditability
  - No redundant status data (except current status in tickets table)
- **Intentional Denormalization**:
  - `status` duplicated in tickets (current) and history (audit)
  - Improves query performance for common operations

### Security Trade-offs

- **RLS Complexity** vs **Application-Level Security**:
  - Chose RLS for ironclad data protection at database level
  - Added slight query complexity for guaranteed security
- **Password Storage**:
  - Only hashed passwords stored (using pgcrypto)

### Scalability Considerations

- **UUIDs** instead of serial PKs for distributed systems
- **Index Strategy**:
  - Balanced between write performance and read speed
  - Covered indexes for common agent/customer queries
- **Partitioning Readiness**:
  - `ticket_status_history` designed for time-based partitioning

## Row-Level Security Implementation

### Policy Design

```sql
-- Customers see only their tickets
CREATE POLICY customer_ticket_policy ON tickets
    FOR SELECT USING (customer_id = current_user_id());

-- Agents see assigned + open tickets  
CREATE POLICY agent_ticket_policy ON tickets
    FOR SELECT USING (agent_id = current_user_id() OR status = 'open');
```
