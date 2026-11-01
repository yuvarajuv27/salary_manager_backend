# frozen_string_literal: true

class AddPeriodBoundsToPayrollRuns < ActiveRecord::Migration[8.1]
  def up
    add_column :payroll_runs, :period_start_on, :date
    add_column :payroll_runs, :period_end_on, :date

    execute <<~SQL.squish
      UPDATE payroll_runs
      SET period_start_on = month_on,
          period_end_on = (month_on + INTERVAL '1 month - 1 day')::date
      WHERE period_start_on IS NULL
    SQL

    change_column_null :payroll_runs, :period_start_on, false
    change_column_null :payroll_runs, :period_end_on, false
  end

  def down
    remove_column :payroll_runs, :period_end_on
    remove_column :payroll_runs, :period_start_on
  end
end
