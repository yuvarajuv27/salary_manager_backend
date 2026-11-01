# frozen_string_literal: true

module Workforce
  module PayslipGuard
    module_function

    def employee_has_payslip?(employee)
      Payslip.exists?(company_id: employee.company_id, employee_id: employee.id)
    end

    def entity_has_payslip?(entity)
      Payslip.exists?(company_id: entity.company_id, entity_id: entity.id)
    end
  end
end
