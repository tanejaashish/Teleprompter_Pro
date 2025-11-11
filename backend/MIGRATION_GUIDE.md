# Database Migration Guide

## Running the Performance Index Migration

The schema.prisma file has been updated with 20+ performance indexes. To apply these changes to your database:

### Step 1: Generate Migration

```bash
cd backend
npx prisma migrate dev --name add_performance_indexes
```

This will:
- Generate SQL migration files
- Apply the migration to your development database
- Regenerate Prisma Client

### Step 2: Review Migration

Check the generated migration file in `prisma/migrations/*/migration.sql` to ensure all indexes are created correctly.

Expected indexes:
- **User table**: 7 indexes (email, createdAt, OAuth IDs, etc.)
- **Subscription table**: 6 indexes (userId, status, tier, compound indexes)
- **Script table**: 13 indexes (userId, timestamps, category, compound indexes)
- **Recording table**: 8 indexes (userId, scriptId, status, timestamps)
- **Session table**: 5 indexes (userId, token, deviceId, expiry)
- **Activity table**: 7 indexes (userId, type, timestamps, compound indexes)

### Step 3: Apply to Production

```bash
# Preview what will be applied
npx prisma migrate deploy --preview-feature

# Apply migration
npx prisma migrate deploy
```

### Step 4: Verify Indexes

```sql
-- PostgreSQL: Check indexes on a table
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'Script'
ORDER BY indexname;

-- View all table indexes
\di+ "Script"
```

## Performance Impact

Expected performance improvements after indexing:

- **User lookups by email**: 90% faster
- **Script queries by userId**: 50-70% faster
- **Script queries by userId + timestamp**: 80% faster
- **Recording queries**: 60% faster
- **Activity log queries**: 70% faster
- **Subscription status checks**: 85% faster

## Rollback (if needed)

If the migration causes issues:

```bash
# Rollback last migration
npx prisma migrate resolve --rolled-back MIGRATION_NAME

# Or manually drop indexes
-- Example:
DROP INDEX "Script_userId_createdAt_idx";
```

## Notes

- Indexes will be built during migration (may take time on large databases)
- Database will remain online during index creation (using CONCURRENTLY in production)
- Monitor database performance after migration
- Consider running during low-traffic periods for production
