# frozen_string_literal: true

class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :entity_id, null: false
      t.text :name, null: false
      t.text :job_role, null: false
      t.text :department, null: false
      t.date :start_on, null: false
      t.date :end_on
      t.text :bank_payload, null: false

      t.timestamps
    end

    add_index :employees, %i[company_id id], unique: true, name: "index_employees_on_company_id_and_id"
    add_index :employees, %i[company_id entity_id id], unique: true, name: "index_employees_on_company_entity_id"

    add_foreign_key :employees, :entities, column: %i[company_id entity_id], primary_key: %i[company_id id]

    add_check_constraint :employees,
                         "end_on IS NULL OR end_on >= start_on",
                         name: "employees_end_on_on_or_after_start_on"
  end
end
