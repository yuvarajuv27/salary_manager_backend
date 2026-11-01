# frozen_string_literal: true

class CreatePayrollSkips < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_skips do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :payroll_run_id, null: false
      t.bigint :entity_id, null: false
      t.bigint :employee_id, null: false
      t.text :reason, null: false

      t.timestamps
    end

    add_index :payroll_skips, %i[payroll_run_id employee_id],
              unique: true,
              name: "index_payroll_skips_on_payroll_run_id_and_employee_id"

    add_foreign_key :payroll_skips, :payroll_runs,
                    column: %i[company_id payroll_run_id],
                    primary_key: %i[company_id id]

    add_foreign_key :payroll_skips, :entities,
                    column: %i[company_id entity_id],
                    primary_key: %i[company_id id]

    add_foreign_key :payroll_skips, :employees,
                    column: %i[company_id entity_id employee_id],
                    primary_key: %i[company_id entity_id id]

    add_check_constraint :payroll_skips,
                         "reason = 'monthly_salary_unset'",
                         name: "payroll_skips_reason_allowed"
  end
end
