CREATE TABLE "Users" (
  "User_id" integer PRIMARY KEY,
  "First_Name" varchar NOT NULL,
  "Last_Name" varchar NOT NULL,
  "Email" varchar UNIQUE CHECK ("Email" ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  "Password" varchar(255) NOT NULL,
  "role" integer
);

CREATE TABLE "Roles" (
  "Role_Id" integer PRIMARY KEY,
  "role" varchar NOT NULL
);

CREATE TABLE "Ticket" (
  "Ticket_id" uuid PRIMARY KEY,
  "User_id" integer,
  "Subject" varchar,
  "Description" text,
  "Status" integer,
  "Priority" integer,
  "Created_at" timestamp,
  "Updated_at" timestamp
);

CREATE TABLE "TicketStatusHistory" (
  "Ticket_id" uuid,
  "Status" integer,
  "Changed_by" integer NOT NULL,
  "Updated_at" timestamp,
  "Description" text NOT NULL,
  "Colour" bigint
);

CREATE TABLE "Priorities" (
  "Priority_id" integer PRIMARY KEY,
  "priority" varchar,
  "color" bigint
);

CREATE TABLE "Status" (
  "Status_id" integer PRIMARY KEY,
  "Status" varchar,
  "Color" bigint
);

-- indexes to improve query performance
-- Removed redundant index on "Users" ("User_id") as PRIMARY KEY already creates a unique index

CREATE INDEX ON "Ticket" ("User_id", "Status");

CREATE INDEX ON "TicketStatusHistory" ("Ticket_id", "Status");

CREATE INDEX ON "Priorities" ("priority");

CREATE INDEX ON "Status" ("Status");

--foreign keys to determine relationships between tables

ALTER TABLE "Users" ADD FOREIGN KEY ("role") REFERENCES "Roles" ("Role_Id") ON DELETE SET NULL;

ALTER TABLE "Ticket" ADD FOREIGN KEY ("User_id") REFERENCES "Users" ("User_id") ON DELETE CASCADE;

ALTER TABLE "Ticket" ADD FOREIGN KEY ("Status") REFERENCES "TicketStatusHistory" ("Status") ON DELETE SET NULL;

ALTER TABLE "Ticket" ADD FOREIGN KEY ("Priority") REFERENCES "Priorities" ("Priority_id") ON DELETE SET NULL;

ALTER TABLE "TicketStatusHistory" ADD FOREIGN KEY ("Ticket_id") REFERENCES "Ticket" ("Ticket_id") ON DELETE CASCADE;

ALTER TABLE "TicketStatusHistory" ADD FOREIGN KEY ("Status") REFERENCES "Status" ("Status_id") ON DELETE SET NULL;

ALTER TABLE "TicketStatusHistory" ADD FOREIGN KEY ("Changed_by") REFERENCES "Users" ("User_id") ON DELETE SET NULL;

ALTER TABLE "Ticket" ENABLE ROW LEVEL SECURITY;

--Create a policy to allow users to see only their own tickets
CREATE POLICY "Users can view their own tickets" ON "Ticket"
  FOR SELECT
  USING ("User_id" = current_setting('app.current_user_id')::integer);
