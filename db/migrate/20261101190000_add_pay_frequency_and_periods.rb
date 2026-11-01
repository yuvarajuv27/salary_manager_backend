# frozen_string_literal: true

class AddPayFrequencyAndPeriods < ActiveRecord::Migration[8.1]
  def up
    add_column :companies, :pay_frequency, :text, null: false, default: "monthly"
    add_column :companies, :pay_weekday, :integer
    add_column :companies, :biweekly_anchor_on, :date

    add_check_constraint :companies,
                         "pay_frequency = ANY (ARRAY['monthly'::text, 'weekly'::text, 'biweekly'::text])",
                         name: "companies_pay_frequency_allowed"
  end

  def down
    remove_check_constraint :companies, name: "companies_pay_frequency_allowed"
    remove_column :companies, :biweekly_anchor_on
    remove_column :companies, :pay_weekday
    remove_column :companies, :pay_frequency
  end
end
