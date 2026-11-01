# frozen_string_literal: true

class CreateCurrencyConversions < ActiveRecord::Migration[8.1]
  def change
    create_table :currency_conversions do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :payroll_run_id, null: false
      t.bigint :entity_id, null: false
      t.text :status, null: false
      t.decimal :rate, precision: 20, scale: 10
      t.date :rate_on
      t.text :primary_currency, null: false
      t.bigint :gross_minor
      t.bigint :net_minor
      t.bigint :employer_cost_minor

      t.timestamps
    end

    add_index :currency_conversions, %i[payroll_run_id entity_id],
              unique: true,
              name: "index_currency_conversions_on_payroll_run_id_and_entity_id"

    add_foreign_key :currency_conversions, :payroll_runs,
                    column: %i[company_id payroll_run_id],
                    primary_key: %i[company_id id]

    add_foreign_key :currency_conversions, :entities,
                    column: %i[company_id entity_id],
                    primary_key: %i[company_id id]

    add_check_constraint :currency_conversions,
                         "status IN ('stored', 'pending')",
                         name: "currency_conversions_status_allowed"

    add_check_constraint :currency_conversions,
                         <<~SQL.squish,
                           (
                             status = 'stored'
                             AND rate IS NOT NULL
                             AND rate_on IS NOT NULL
                             AND gross_minor IS NOT NULL
                             AND net_minor IS NOT NULL
                             AND employer_cost_minor IS NOT NULL
                           )
                           OR (
                             status = 'pending'
                             AND rate IS NULL
                             AND rate_on IS NULL
                             AND gross_minor IS NULL
                             AND net_minor IS NULL
                             AND employer_cost_minor IS NULL
                           )
                         SQL
                         name: "currency_conversions_stored_shape"
  end
end
