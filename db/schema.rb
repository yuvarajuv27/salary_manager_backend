# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_01_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", force: :cascade do |t|
    t.text "legal_name", null: false
    t.text "primary_currency", null: false
    t.integer "payroll_day", default: 31, null: false
    t.date "next_payroll_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "pay_frequency", default: "monthly", null: false
    t.integer "pay_weekday"
    t.date "biweekly_anchor_on"
    t.check_constraint "pay_frequency = ANY (ARRAY['monthly'::text, 'weekly'::text, 'biweekly'::text])", name: "companies_pay_frequency_allowed"
    t.check_constraint "payroll_day >= 1 AND payroll_day <= 31", name: "companies_payroll_day_range"
  end

  create_table "currency_conversions", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "payroll_run_id", null: false
    t.bigint "entity_id", null: false
    t.text "status", null: false
    t.decimal "rate", precision: 20, scale: 10
    t.date "rate_on"
    t.text "primary_currency", null: false
    t.bigint "gross_minor"
    t.bigint "net_minor"
    t.bigint "employer_cost_minor"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_currency_conversions_on_company_id"
    t.index ["payroll_run_id", "entity_id"], name: "index_currency_conversions_on_payroll_run_id_and_entity_id", unique: true
    t.check_constraint "status = 'stored'::text AND rate IS NOT NULL AND rate_on IS NOT NULL AND gross_minor IS NOT NULL AND net_minor IS NOT NULL AND employer_cost_minor IS NOT NULL OR status = 'pending'::text AND rate IS NULL AND rate_on IS NULL AND gross_minor IS NULL AND net_minor IS NULL AND employer_cost_minor IS NULL", name: "currency_conversions_stored_shape"
    t.check_constraint "status = ANY (ARRAY['stored'::text, 'pending'::text])", name: "currency_conversions_status_allowed"
  end

  create_table "employees", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "entity_id", null: false
    t.text "name", null: false
    t.text "job_role", null: false
    t.text "department", null: false
    t.date "start_on", null: false
    t.date "end_on"
    t.text "bank_payload", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "entity_id", "id"], name: "index_employees_on_company_entity_id", unique: true
    t.index ["company_id", "id"], name: "index_employees_on_company_id_and_id", unique: true
    t.index ["company_id"], name: "index_employees_on_company_id"
    t.check_constraint "end_on IS NULL OR end_on >= start_on", name: "employees_end_on_on_or_after_start_on"
  end

  create_table "entities", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.text "name", null: false
    t.text "country", null: false
    t.text "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "id"], name: "index_entities_on_company_id_and_id", unique: true
    t.index ["company_id"], name: "index_entities_on_company_id"
  end

  create_table "entity_credits", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "payroll_run_id", null: false
    t.bigint "entity_id", null: false
    t.text "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_entity_credits_on_company_id"
    t.index ["payroll_run_id", "entity_id"], name: "index_entity_credits_on_payroll_run_id_and_entity_id", unique: true
    t.check_constraint "status = ANY (ARRAY['processing'::text, 'credited'::text])", name: "entity_credits_status_allowed"
  end

  create_table "leave_days", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "employee_id", null: false
    t.date "leave_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_leave_days_on_company_id"
    t.index ["employee_id", "leave_on"], name: "index_leave_days_on_employee_id_and_leave_on", unique: true
  end

  create_table "pay_rules", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "entity_id", null: false
    t.text "name", null: false
    t.integer "position", null: false
    t.text "side", null: false
    t.text "kind", null: false
    t.decimal "percent", precision: 7, scale: 4
    t.bigint "amount_minor"
    t.bigint "ceiling_minor"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_pay_rules_on_company_id"
    t.check_constraint "\"position\" >= 0", name: "pay_rules_position_non_negative"
    t.check_constraint "kind = ANY (ARRAY['percent'::text, 'fixed'::text])", name: "pay_rules_kind_allowed"
    t.check_constraint "side = 'earning'::text AND kind = 'percent'::text AND percent > 0::numeric AND percent <= 100::numeric AND amount_minor IS NULL AND ceiling_minor IS NULL OR (side = ANY (ARRAY['employee_deduction'::text, 'employer_contribution'::text])) AND kind = 'percent'::text AND percent > 0::numeric AND percent <= 100::numeric AND amount_minor IS NULL AND (ceiling_minor IS NULL OR ceiling_minor > 0) OR (side = ANY (ARRAY['employee_deduction'::text, 'employer_contribution'::text])) AND kind = 'fixed'::text AND amount_minor > 0 AND percent IS NULL AND ceiling_minor IS NULL", name: "pay_rules_shape"
    t.check_constraint "side = ANY (ARRAY['earning'::text, 'employee_deduction'::text, 'employer_contribution'::text])", name: "pay_rules_side_allowed"
  end

  create_table "payroll_runs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.date "month_on", null: false
    t.date "payroll_on", null: false
    t.text "primary_currency", null: false
    t.text "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "period_start_on", null: false
    t.date "period_end_on", null: false
    t.index ["company_id", "id"], name: "index_payroll_runs_on_company_id_and_id", unique: true
    t.index ["company_id", "month_on"], name: "index_payroll_runs_on_company_id_and_month_on", unique: true
    t.index ["company_id"], name: "index_payroll_runs_on_company_id"
    t.check_constraint "status = ANY (ARRAY['processing'::text, 'credited'::text])", name: "payroll_runs_status_allowed"
  end

  create_table "payroll_skips", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "payroll_run_id", null: false
    t.bigint "entity_id", null: false
    t.bigint "employee_id", null: false
    t.text "reason", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_payroll_skips_on_company_id"
    t.index ["payroll_run_id", "employee_id"], name: "index_payroll_skips_on_payroll_run_id_and_employee_id", unique: true
    t.check_constraint "reason = 'monthly_salary_unset'::text", name: "payroll_skips_reason_allowed"
  end

  create_table "payslips", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "payroll_run_id", null: false
    t.bigint "entity_id", null: false
    t.bigint "employee_id", null: false
    t.text "currency", null: false
    t.integer "payable_days", null: false
    t.integer "leave_days_count", null: false
    t.integer "outside_days", null: false
    t.bigint "salary_minor", null: false
    t.bigint "gross_minor", null: false
    t.bigint "net_minor", null: false
    t.bigint "employer_cost_minor", null: false
    t.jsonb "lines", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_payslips_on_company_id"
    t.index ["payroll_run_id", "employee_id"], name: "index_payslips_on_payroll_run_id_and_employee_id", unique: true
    t.check_constraint "employer_cost_minor >= 0", name: "payslips_employer_cost_minor_non_negative"
    t.check_constraint "gross_minor >= 0", name: "payslips_gross_minor_non_negative"
    t.check_constraint "leave_days_count >= 0", name: "payslips_leave_days_count_non_negative"
    t.check_constraint "net_minor >= 0", name: "payslips_net_minor_non_negative"
    t.check_constraint "outside_days >= 0", name: "payslips_outside_days_non_negative"
    t.check_constraint "payable_days >= 0", name: "payslips_payable_days_non_negative"
    t.check_constraint "salary_minor >= 0", name: "payslips_salary_minor_non_negative"
  end

  create_table "salary_assignments", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "employee_id", null: false
    t.date "effective_on", null: false
    t.bigint "amount_minor", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_salary_assignments_on_company_id"
    t.index ["employee_id", "effective_on"], name: "index_salary_assignments_on_employee_id_and_effective_on", unique: true
    t.check_constraint "amount_minor >= 0", name: "salary_assignments_amount_minor_non_negative"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "entity_id"
    t.text "name", null: false
    t.text "email", null: false
    t.text "password_digest", null: false
    t.text "access_role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "access_role = 'hr'::text AND entity_id IS NOT NULL OR access_role = 'admin'::text AND entity_id IS NULL", name: "users_entity_id_matches_access_role"
  end

  add_foreign_key "currency_conversions", "companies"
  add_foreign_key "currency_conversions", "entities", column: ["company_id", "entity_id"], primary_key: ["company_id", "id"]
  add_foreign_key "currency_conversions", "payroll_runs", column: ["company_id", "payroll_run_id"], primary_key: ["company_id", "id"]
  add_foreign_key "employees", "companies"
  add_foreign_key "employees", "entities", column: ["company_id", "entity_id"], primary_key: ["company_id", "id"]
  add_foreign_key "entities", "companies"
  add_foreign_key "entity_credits", "companies"
  add_foreign_key "entity_credits", "entities", column: ["company_id", "entity_id"], primary_key: ["company_id", "id"]
  add_foreign_key "entity_credits", "payroll_runs", column: ["company_id", "payroll_run_id"], primary_key: ["company_id", "id"]
  add_foreign_key "leave_days", "companies"
  add_foreign_key "leave_days", "employees", column: ["company_id", "employee_id"], primary_key: ["company_id", "id"]
  add_foreign_key "pay_rules", "companies"
  add_foreign_key "pay_rules", "entities", column: ["company_id", "entity_id"], primary_key: ["company_id", "id"]
  add_foreign_key "payroll_runs", "companies"
  add_foreign_key "payroll_skips", "companies"
  add_foreign_key "payroll_skips", "employees", column: ["company_id", "entity_id", "employee_id"], primary_key: ["company_id", "entity_id", "id"]
  add_foreign_key "payroll_skips", "entities", column: ["company_id", "entity_id"], primary_key: ["company_id", "id"]
  add_foreign_key "payroll_skips", "payroll_runs", column: ["company_id", "payroll_run_id"], primary_key: ["company_id", "id"]
  add_foreign_key "payslips", "companies"
  add_foreign_key "payslips", "employees", column: ["company_id", "entity_id", "employee_id"], primary_key: ["company_id", "entity_id", "id"]
  add_foreign_key "payslips", "entities", column: ["company_id", "entity_id"], primary_key: ["company_id", "id"]
  add_foreign_key "payslips", "payroll_runs", column: ["company_id", "payroll_run_id"], primary_key: ["company_id", "id"]
  add_foreign_key "salary_assignments", "companies"
  add_foreign_key "salary_assignments", "employees", column: ["company_id", "employee_id"], primary_key: ["company_id", "id"]
  add_foreign_key "users", "companies"
  add_foreign_key "users", "entities", column: ["company_id", "entity_id"], primary_key: ["company_id", "id"]
end
