# Salary Manager Implementation Plan (Backend)

> **Canonical plan (milestones, FE+BE tasks, gates):** [salary_manager_frontend/docs/plans/salary-manager.md](../../../salary_manager_frontend/docs/plans/salary-manager.md)
>
> **For agentic workers:** Follow that document. This file lists **backend-owned** work only so BE sessions can stay in this repo. Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Checkbox tracking may be mirrored here when executing BE-only.
>
> **Git (project override):** Do not commit/push/PR unless the user explicitly asks.

**Goal:** Implement the Rails API, schema, calculator, Solid Queue payroll clock, Frankfurter conversion, and analytics reads defined in `docs/architecture/salary-manager.md`, against product requirements in the frontend `docs/requirements/project.md`.

**Architecture:** See `docs/architecture/salary-manager.md`. PostgreSQL is system of record. Session cookie auth. Company-scoped authorization (404 cross-tenant). One `PayCalculator` for preview and credit.

**Tech Stack:** Rails `~> 8.1.4`, PostgreSQL, Solid Queue, bcrypt, Active Record Encryption, HTTParty, RSpec.

## Global Constraints

Copy from the canonical plan (money minor units, UTC payroll clock, nine countries, 401/404/422 contract, no Devise/Pundit/Sidekiq/Money gem).

## Backend milestones (map to canonical)

| Milestone | BE focus | Primary paths |
|---|---|---|
| **M0** | RSpec, bcrypt, httparty, session middleware, CORS credentials, encryption keys | `Gemfile`, `config/application.rb`, `config/initializers/*` |
| **M1** | `companies`, `users`, sign_up, session, `PayrollCalendar` | `app/models/*`, `app/controllers/sign_ups_controller.rb`, `sessions_controller.rb`, `app/services/payroll_calendar.rb` |
| **M2** | Entities, company PATCH, users invite, HR scoping | `entities_controller.rb`, `companies_controller.rb`, `users_controller.rb`, `app/services/countries.rb` |
| **M3** | `pay_rules`, `PayCalculator`, preview API | `app/services/pay_calculator.rb`, `pay_rules_controller.rb` |
| **M4** | Employees, bank encryption/mask, salary writer, leave, country change | `bank_details.rb`, `salary_writer.rb`, employee/salary/leave controllers |
| **M5** | Payroll tables, scheduler, entity credit, payslip reads, immutability | `app/jobs/*`, payroll models/controllers |
| **M6** | Frankfurter, conversions, analytics services/API | `frankfurter_client.rb`, `currency_conversion_job.rb`, `app/services/analytics/*` |

## File map

Use the Backend table in the canonical plan (`salary_manager_frontend/docs/plans/salary-manager.md` § File map).

## Task checklist (BE only)

Execute tasks in the canonical plan with these IDs; skip FE-only tasks (M0.3, M0.4, M1.3, M2.3, M3.4, M4.3, M5.5, M6.3) when working BE-only — coordinate so FE tasks land after their API contracts exist.

- [ ] M0.1 Backend test + gem baseline
- [ ] M0.2 Session middleware, CORS credentials, encryption config
- [ ] M1.1 Companies + Users schema and models
- [ ] M1.2 Sign up + session API
- [ ] M2.1 Entities schema + country currency map
- [ ] M2.2 Entities + company + users API + HR scoping
- [ ] M3.1 `pay_rules` table + model validations
- [ ] M3.2 PayCalculator service
- [ ] M3.3 Pay rules API + preview
- [ ] M4.1 Employees, salary_assignments, leave_days + bank encryption
- [ ] M4.2 Employees / salary / leave / country-change API
- [ ] M5.1 Payroll tables
- [ ] M5.2 Entity credit job + payable days
- [ ] M5.3 Scheduler + batch finish
- [ ] M5.4 Payslip read APIs + immutability
- [ ] M6.1 Frankfurter client + conversion job
- [ ] M6.2 Analytics services + API

## Verification

Per-task commands live in the canonical plan. Milestone gates that are BE-complete:

```bash
cd /Users/yuvaraj/Personal/salary_manager_backend && bundle exec rspec
```

Do not claim a milestone done until its BE request/job/service specs listed in `docs/architecture/salary-manager.md` § Testing are green for that milestone’s scope.
