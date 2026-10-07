# Database

PostgreSQL 16, schema per docs §29.

## Tables

```
sources(id, name, url, type, enabled, category, last_checked_at, created_at)
categories(id, name unique, description)
articles(id, url, canonical_url unique, title, source_id fk, author,
         published_at, discovered_at, summary, what_happened, why_it_matters,
         importance_score, content_hash, processing_status,
         created_at, updated_at)
article_categories(article_id fk, category_id fk)        -- composite PK
bookmarks(id, article_id fk, created_at)
users(id, username unique, email, is_active, created_at)
devices(id, user_id fk, name, platform, token_hash, last_seen_at, created_at)
processing_jobs(id, started_at, finished_at, status,
                articles_found, articles_processed, articles_failed, error)
```

## Statuses (docs §39)

```
DISCOVERED → PROCESSING → PROCESSED
                          ↘ FAILED → PROCESSING (next scheduler tick)
```

## Constraints

- `articles.canonical_url` UNIQUE — first line of duplicate defence (docs §13, §40).
- `articles.content_hash` indexed — second line.
- `articles.processing_status` indexed — fast worker queries.

## Backups (docs §49)

- Daily `pg_dump` to `/backups/`.
- Keep 7 daily + 4 weekly.
- Rotate offsite (e.g. `rclone` to a private bucket) in Phase 8.