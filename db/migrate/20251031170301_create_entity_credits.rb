# frozen_string_literal: true

class CreateEntityCredits < ActiveRecord::Migration[8.1]
  def change
    create_table :entity_credits do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :payroll_run_id, null: false
      t.bigint :entity_id, null: false
      t.text :status, null: false

      t.timestamps
    end

    add_index :entity_credits, %i[payroll_run_id entity_id],
              unique: true,
              name: "index_entity_credits_on_payroll_run_id_and_entity_id"

    add_foreign_key :entity_credits, :payroll_runs,
                    column: %i[company_id payroll_run_id],
                    primary_key: %i[company_id id]

    add_foreign_key :entity_credits, :entities,
                    column: %i[company_id entity_id],
                    primary_key: %i[company_id id]

    add_check_constraint :entity_credits,
                         "status IN ('processing', 'credited')",
                         name: "entity_credits_status_allowed"
  end
end
