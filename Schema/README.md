
 # Entities
I decided to have a separate table for roles, status, and priority for flexibility purposes, and since the dataset is small, I consider that it has a minuscule impact on time complexity.

 # Row-Level Security (RLS)

-Users: Can only view their own tickets

# Auditability

- All tables include `created_at` and `updated_at`
- Ticket status changes are tracked in `ticket_status_history`, and user changes are monitored by the `changed_by` attribute

 # Scalability
- Indexed foreign keys
- Did not normalize the Roles, Status and Priority tables for the purposes of  flexibility and give the administrator of the system much more control over the system.

