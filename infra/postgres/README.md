# PostgreSQL (`infra/postgres`)

PostgreSQL provides relational persistence for ForgetMeNot platform data.

## Tech Stack

`PostgreSQL` `psql` `Docker` `Docker Compose`

## Stack Audit

### Current stack tags

`PostgreSQL` `psql` `Docker` `Docker Compose`

### What this means in this project

- `PostgreSQL`: primary relational storage engine for structured data.
- `psql`: direct query and connectivity checks.
- `Docker Compose`: repeatable local deployment lifecycle.

### Professional additions recommended

- Schema migration workflow (Alembic/Flyway/Liquibase)
- Role-based access model and least-privilege DB users
- Automated backup and point-in-time recovery strategy
- Indexing and slow-query monitoring process
- Connection pool tuning and max-connections policy
- Data lifecycle policy (retention, archival, and cleanup)

## Docker Compose service

- Service name: `postgres`
- Image: `postgres:16-alpine`
- Container name: `forgetmenot-postgres`
- Port mapping: `5432:5432`
- Volume: `postgres_data:/var/lib/postgresql/data`

Default credentials from `docker-compose.yml`:

- Database: `forgetmenot`
- User: `forgetmenot`
- Password: `forgetmenot`

## Operational notes

- Credentials are development defaults and should be replaced outside local environments.
- Persistent database files are stored in `postgres_data`.
- Any schema changes should be migration-managed for safe upgrades.

## Start only PostgreSQL

From repo root:

```bash
docker compose up -d postgres
```

## Verify PostgreSQL

```bash
docker compose ps postgres
docker exec -it forgetmenot-postgres psql -U forgetmenot -d forgetmenot -c "SELECT 1;"
docker exec -it forgetmenot-postgres psql -U forgetmenot -d forgetmenot -c "\l"
```

## Connection from backend

Configured via environment in `docker-compose.yml`:

- `POSTGRES_HOST=postgres`
- `POSTGRES_PORT=5432`

## Troubleshooting

- **Auth failed:** verify username/password in compose and backend env.
- **Port conflict on 5432:** stop local Postgres service or remap compose port.
- **Data missing after restart:** check that `postgres_data` volume exists and is mounted.
- **Slow responses:** inspect indexes and query plans.
