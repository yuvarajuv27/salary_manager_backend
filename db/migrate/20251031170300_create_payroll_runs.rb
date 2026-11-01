# frozen_string_literal: true

class CreatePayrollRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_runs do |t|
      t.references :company, null: false, foreign_key: true
      t.date :month_on, null: false
      t.date :payroll_on, null: false
      t.text :primary_currency, null: false
      t.text :status, null: false

      t.timestamps
    end

    add_index :payroll_runs, %i[company_id month_on], unique: true, name: "index_payroll_runs_on_company_id_and_month_on"
    add_index :payroll_runs, %i[company_id id], unique: true, name: "index_payroll_runs_on_company_id_and_id"

    add_check_constraint :payroll_runs,
                         "status IN ('processing', 'credited')",
                         name: "payroll_runs_status_allowed"
  end
end
