# Migration Safety Checklist

> Reference for `/migrate`. Pre-flight checks that prevent the most common migration disasters. Each check is binary; the skill MUST report each one before applying.

## Universal pre-flight (all environments)

### M1. Migration file exists and is readable
**Check:** the file path resolves and the content is valid SQL or migration tool format.

### M2. Migration is idempotent OR has a guard
**Check:** the SQL contains one of:
- `IF NOT EXISTS` (CREATE INDEX, CREATE TABLE)
- `IF EXISTS` (DROP)
- An explicit version check
- Tracked by a migration tool that prevents re-runs (alembic, knex, prisma)

If none of these, **warn**: "Re-running this migration will fail."

### M3. Down migration / rollback exists
**Check:** the migration has a documented rollback. Either:
- A separate `_down.sql` or `down()` function in the same file
- An explicit `-- ROLLBACK:` comment block
- The user confirms they'll restore from backup if needed

### M4. No `DROP DATABASE`
**Check:** never. If the migration contains `DROP DATABASE`, refuse and ask the user what they're really trying to do.

### M5. No `TRUNCATE` without explicit confirmation
**Check:** `TRUNCATE` deletes all rows, often non-recoverable. If present, halt and confirm.

---

## PostgreSQL-specific

### PG1. `ADD COLUMN NOT NULL DEFAULT` is safe on PostgreSQL 11+
On PG ≥ 11, this is fast (no table rewrite). On PG < 11, it locks the table for the duration of a full table rewrite — can be hours.

**Check:** detect PG version. If < 11 AND migration has `ADD COLUMN NOT NULL DEFAULT`, suggest splitting into:
1. `ADD COLUMN ... NULL` (instant)
2. Backfill in batches
3. `ALTER COLUMN ... SET NOT NULL` (instant after backfill)
4. `ALTER COLUMN ... SET DEFAULT ...` (instant)

### PG2. `CREATE INDEX` should use `CONCURRENTLY` on production
**Check:** if production AND large table (>100k rows estimated), the migration should use `CREATE INDEX CONCURRENTLY ... IF NOT EXISTS`. Without `CONCURRENTLY`, the table is locked for writes for the duration.

Note: `CONCURRENTLY` cannot be used inside a transaction. The migration tool must be configured to run it outside a tx (alembic: `op.execute(text(...))` with `op.get_context().autocommit_block()`).

### PG3. `ALTER COLUMN TYPE` rewrites the table
**Check:** halt for any table > 1M rows. Suggest the multi-step plan (new column → backfill → switch reads → switch writes → drop old).

### PG4. Foreign key constraints add slowly
**Check:** `ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY ... REFERENCES ...` validates ALL existing rows, locking the table. Suggest:
1. `ALTER TABLE ... ADD CONSTRAINT ... NOT VALID` (instant, applies to new rows only)
2. `ALTER TABLE ... VALIDATE CONSTRAINT ...` (validates existing rows without exclusive lock)

### PG5. `RENAME COLUMN` is safe but breaks running queries
**Check:** if the application has live traffic, RENAME breaks any prepared statement using the old name. Better: ADD new name → switch app → DROP old name (3 deploys).

### PG6. `VACUUM FULL` rewrites the entire table
**Check:** halt. Use `VACUUM` (no FULL) or `pg_repack` for online compaction. Never `VACUUM FULL` on prod without scheduled downtime.

---

## MySQL-specific

### MY1. `ALTER TABLE` rewrites by default
**Check:** MySQL ALTER TABLE traditionally rewrites the entire table. On MySQL 5.6+, some operations support `ALGORITHM=INPLACE, LOCK=NONE`, but not all. If the migration uses ALTER TABLE on a table > 100k rows, suggest using `pt-online-schema-change` or `gh-ost` for online schema migration.

### MY2. `DROP COLUMN` requires `ALGORITHM=INPLACE` to avoid lock
**Check:** verify `ALGORITHM=INPLACE, LOCK=NONE` is added when supported.

### MY3. Implicit commits
**Check:** MySQL DDL implicitly commits any open transaction. The migration cannot be wrapped in BEGIN/ROLLBACK. Each DDL statement is its own transaction. Plan rollback as separate down statements, not transactions.

---

## SQLite-specific

### SQ1. Limited ALTER TABLE
SQLite supports only:
- `ALTER TABLE ... RENAME TO ...`
- `ALTER TABLE ... RENAME COLUMN ... TO ...` (3.25+)
- `ALTER TABLE ... ADD COLUMN ...`
- `ALTER TABLE ... DROP COLUMN ...` (3.35+)

For anything else (change column type, drop constraint, etc.), the canonical workaround is:
1. `CREATE TABLE new_table AS SELECT ... FROM old_table`
2. Apply schema changes via `CREATE TABLE` with new definition
3. `INSERT INTO new_table SELECT ... FROM old_table`
4. `DROP TABLE old_table`
5. `ALTER TABLE new_table RENAME TO old_table`

### SQ2. WAL mode for safer migrations
**Check:** if the database isn't in WAL mode (`PRAGMA journal_mode`), enabling it first reduces lock duration during migrations.

---

## Backup commands cheat sheet

```bash
# PostgreSQL — full database, custom format (best for restore)
pg_dump -Fc -f /tmp/backup-$(date +%s).dump $DATABASE_URL

# PostgreSQL — single table only
pg_dump -Fc -t users -f /tmp/users-$(date +%s).dump $DATABASE_URL

# MySQL — full database with single transaction (consistent snapshot)
mysqldump --single-transaction --quick --routines --triggers \
  $DB_NAME > /tmp/backup-$(date +%s).sql

# SQLite — file copy (must stop writers first OR use .backup)
sqlite3 $DB_FILE ".backup /tmp/backup-$(date +%s).db"

# Docker-wrapped Postgres
docker exec db pg_dump -Fc -U postgres app > /tmp/backup-$(date +%s).dump
```

## Restore commands cheat sheet

```bash
# PostgreSQL — restore from custom format
pg_restore -c -d $DATABASE_URL /tmp/backup-1712345678.dump

# PostgreSQL — restore single table
pg_restore -c -t users -d $DATABASE_URL /tmp/users-1712345678.dump

# MySQL
mysql $DB_NAME < /tmp/backup-1712345678.sql

# SQLite
sqlite3 $DB_FILE ".restore /tmp/backup-1712345678.db"
```

## Anti-patterns

### "It's just a small change, no backup needed"
Famous last words. Always backup before DDL on shared databases.

### "I'll add a NOT NULL column without a default"
This fails immediately on any non-empty table. Always either DEFAULT or NULL-first-then-backfill.

### "I'll rename and deploy in one step"
Breaks all running queries. Always: add new → switch reads → switch writes → drop old, across 3 deploys.

### "I'll just truncate this large table to clean up"
TRUNCATE doesn't free disk space until VACUUM (Postgres). And it's irreversible. Use DELETE WHERE for selective cleanup, or backup first.

### "Foreign key constraint, no problem"
On a 10M row table, validating an FK locks the table for minutes-to-hours. Use `NOT VALID` then `VALIDATE` separately.

### "This migration is idempotent because it's wrapped in a transaction"
DDL is mostly transactional in PostgreSQL but NOT in MySQL. SQLite is partial. Don't trust transactions for DDL safety; use `IF NOT EXISTS` and similar guards.

### "We have a backup somewhere, I think"
"I think" = no backup. Verify the backup exists and is restorable BEFORE applying the migration.

---

## When to refuse

Refuse to proceed (and ask the user what they really want) when ANY of these is true:

- Production environment + no backup taken yet
- Migration contains `DROP DATABASE`
- Migration contains `TRUNCATE` without explicit confirmation in `$ARGUMENTS`
- Migration contains `ALTER COLUMN TYPE` on a table with > 1M rows
- Migration contains `CREATE INDEX` (without CONCURRENTLY) on a production table > 100k rows
- The migration tool's tracker says this version is already applied

For each refusal, explain WHY and propose a safe alternative.
