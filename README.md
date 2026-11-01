# Salary Manager (Backend)

Rails API for **Salary Manager**: multi-company Admin/HR payroll for legal entities in nine countries. Owns records, money math, authorization, Solid Queue payroll credit, Frankfurter FX conversion, and analytics reads.

**Whole-project product requirements are canonical in the frontend repo** — do not duplicate them here. Sibling client: [salary_manager_frontend](../salary_manager_frontend).

## What this API does

- Session cookie auth (`_salary_manager_session`, `SameSite=Lax`) — no Devise/Pundit
- Company isolation; Admin vs HR scoping (cross-tenant / wrong entity → **404**)
- Entities, users, pay rules + preview (`PayCalculator`), employees with encrypted bank details
- Salary correction/revision, leave, country change with bank replace
- Hourly `PayrollSchedulerJob` → entity credits → payslips/skips → run finisher
- Currency conversions (Frankfurter / ECB rates) and entity/account analytics
- Optional demo seed: `rake seed:load_demo` (10 entities × 1k employees by default)

Amounts on the wire are integer **minor units** plus currency code. Clock is **UTC** only.

## Stack

| Piece | Choice |
|---|---|
| Framework | Rails `~> 8.1.4` (API-only + cookie session) |
| DB / jobs | PostgreSQL 16, Solid Queue |
| Auth | `bcrypt` / `has_secure_password` |
| Encryption | Active Record Encryption (bank payload) |
| FX | HTTParty → [Frankfurter](https://www.frankfurter.app/) |
| Tests | RSpec |

## Docs

| Path | Purpose |
|---|---|
| [docs/README.md](./docs/README.md) | Docs index for this repo |
| [docs/requirements/README.md](./docs/requirements/README.md) | Pointer to FE canonical requirements |
| [docs/architecture/salary-manager.md](./docs/architecture/salary-manager.md) | Backend architecture (DB, API, payroll) |
| [docs/plans/salary-manager.md](./docs/plans/salary-manager.md) | Backend companion plan (links to FE milestones) |
| [docs/SUPERPOWERS_INSTALL.md](./docs/SUPERPOWERS_INSTALL.md) | Install Superpowers at **project** scope |

Canonical product FRs and the full M0–M6 plan:

- https://github.com/yuvarajuv27/salary_manager_frontend/blob/main/docs/requirements/project.md  
- https://github.com/yuvarajuv27/salary_manager_frontend/blob/main/docs/plans/salary-manager.md  

Feature work follows Superpowers: brainstorm → requirements → architecture → plan → TDD (RSpec).

## Local development

### Docker Compose (recommended)

```bash
docker compose up --build
```

| Service | Default |
|---|---|
| API | `http://localhost:3000` |
| Postgres | `localhost:5432` (user/password `postgres`) |

Compose supplies local-only encryption keys and `CORS_ORIGINS` for Vite (`5173` / `5174`).

Inside the running backend container:

```bash
docker compose exec backend bash -lc 'bundle install && bundle exec rails db:prepare'
docker compose exec backend bash -lc 'RAILS_ENV=test bundle exec rspec'
```

### Native Rails (optional)

Ruby **3.4**, PostgreSQL, then:

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

Set the same env vars as in `docker-compose.yml` (`DB_*`, `CORS_ORIGINS`, Active Record Encryption keys).

### Useful env

| Variable | Purpose |
|---|---|
| `CORS_ORIGINS` | Comma-separated Vite origins (credentials enabled; not `*`) |
| `ACTIVE_RECORD_ENCRYPTION_*` | Primary / deterministic / salt keys |
| `DB_HOST` / `DB_USERNAME` / `DB_PASSWORD` | Postgres |

### Demo seed

```bash
docker compose exec backend bash -lc 'bundle exec rake seed:load_demo'
```

Aborts if the seed Admin email already exists. Tunables for tests: `entity_count`, `employees_per_entity` on `DemoSeedLoader`.

### Tests

```bash
docker compose exec backend bash -lc 'RAILS_ENV=test bundle exec rspec'
```

## Related repo

| Repo | Role |
|---|---|
| [salary_manager_frontend](../salary_manager_frontend) | React UI; **canonical** product requirements and whole-release plan |

Deployed FE and API must stay same-site so the session cookie is sent.
