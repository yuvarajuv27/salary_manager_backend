# frozen_string_literal: true

class CreateLeaveDays < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_days do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :employee_id, null: false
      t.date :leave_on, null: false

      t.timestamps
    end

    add_index :leave_days, %i[employee_id leave_on], unique: true

    add_foreign_key :leave_days, :employees,
                    column: %i[company_id employee_id],
                    primary_key: %i[company_id id]
  end
end
