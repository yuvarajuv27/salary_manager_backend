# frozen_string_literal: true

class CreatePayslips < ActiveRecord::Migration[8.1]
  def change
    create_table :payslips do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :payroll_run_id, null: false
      t.bigint :entity_id, null: false
      t.bigint :employee_id, null: false
      t.text :currency, null: false
      t.integer :payable_days, null: false
      t.integer :leave_days_count, null: false
      t.integer :outside_days, null: false
      t.bigint :salary_minor, null: false
      t.bigint :gross_minor, null: false
      t.bigint :net_minor, null: false
      t.bigint :employer_cost_minor, null: false
      t.jsonb :lines, null: false, default: []

      t.timestamps
    end

    add_index :payslips, %i[payroll_run_id employee_id],
              unique: true,
              name: "index_payslips_on_payroll_run_id_and_employee_id"

    add_foreign_key :payslips, :payroll_runs,
                    column: %i[company_id payroll_run_id],
                    primary_key: %i[company_id id]

    add_foreign_key :payslips, :entities,
                    column: %i[company_id entity_id],
                    primary_key: %i[company_id id]

    add_foreign_key :payslips, :employees,
                    column: %i[company_id entity_id employee_id],
                    primary_key: %i[company_id entity_id id]

    add_check_constraint :payslips, "payable_days >= 0", name: "payslips_payable_days_non_negative"
    add_check_constraint :payslips, "leave_days_count >= 0", name: "payslips_leave_days_count_non_negative"
    add_check_constraint :payslips, "outside_days >= 0", name: "payslips_outside_days_non_negative"
    add_check_constraint :payslips, "salary_minor >= 0", name: "payslips_salary_minor_non_negative"
    add_check_constraint :payslips, "gross_minor >= 0", name: "payslips_gross_minor_non_negative"
    add_check_constraint :payslips, "net_minor >= 0", name: "payslips_net_minor_non_negative"
    add_check_constraint :payslips, "employer_cost_minor >= 0", name: "payslips_employer_cost_minor_non_negative"
  end
end
