# frozen_string_literal: true

class CreateSalaryAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_assignments do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :employee_id, null: false
      t.date :effective_on, null: false
      t.bigint :amount_minor, null: false

      t.timestamps
    end

    add_index :salary_assignments, %i[employee_id effective_on], unique: true

    add_foreign_key :salary_assignments, :employees,
                    column: %i[company_id employee_id],
                    primary_key: %i[company_id id]

    add_check_constraint :salary_assignments,
                         "amount_minor >= 0",
                         name: "salary_assignments_amount_minor_non_negative"
  end
end
