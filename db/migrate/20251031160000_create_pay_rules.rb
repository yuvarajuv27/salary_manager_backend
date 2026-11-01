# frozen_string_literal: true

class CreatePayRules < ActiveRecord::Migration[8.1]
  def change
    create_table :pay_rules do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :entity_id, null: false
      t.text :name, null: false
      t.integer :position, null: false
      t.text :side, null: false
      t.text :kind, null: false
      t.decimal :percent, precision: 7, scale: 4
      t.bigint :amount_minor
      t.bigint :ceiling_minor

      t.timestamps
    end

    add_foreign_key :pay_rules, :entities, column: %i[company_id entity_id], primary_key: %i[company_id id]

    add_check_constraint :pay_rules, "position >= 0", name: "pay_rules_position_non_negative"

    add_check_constraint :pay_rules,
                         "side IN ('earning', 'employee_deduction', 'employer_contribution')",
                         name: "pay_rules_side_allowed"

    add_check_constraint :pay_rules,
                         "kind IN ('percent', 'fixed')",
                         name: "pay_rules_kind_allowed"

    add_check_constraint :pay_rules,
                         <<~SQL.squish,
                           (
                             side = 'earning'
                             AND kind = 'percent'
                             AND percent > 0 AND percent <= 100
                             AND amount_minor IS NULL
                             AND ceiling_minor IS NULL
                           )
                           OR (
                             side IN ('employee_deduction', 'employer_contribution')
                             AND kind = 'percent'
                             AND percent > 0 AND percent <= 100
                             AND amount_minor IS NULL
                             AND (ceiling_minor IS NULL OR ceiling_minor > 0)
                           )
                           OR (
                             side IN ('employee_deduction', 'employer_contribution')
                             AND kind = 'fixed'
                             AND amount_minor > 0
                             AND percent IS NULL
                             AND ceiling_minor IS NULL
                           )
                         SQL
                         name: "pay_rules_shape"
  end
end
