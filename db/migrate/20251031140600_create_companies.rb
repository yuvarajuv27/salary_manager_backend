# frozen_string_literal: true

class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.text :legal_name, null: false
      t.text :primary_currency, null: false
      t.integer :payroll_day, null: false, default: 31
      t.date :next_payroll_on, null: false

      t.timestamps
    end

    add_check_constraint :companies,
                         "payroll_day >= 1 AND payroll_day <= 31",
                         name: "companies_payroll_day_range"
  end
end
