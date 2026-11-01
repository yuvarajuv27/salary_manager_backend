# frozen_string_literal: true

class CurrencyConversionJob < ApplicationJob
  def perform(_payroll_run_id, _entity_id)
    # Frankfurter fetch + stored conversion totals land in M6.
  end
end
