# frozen_string_literal: true

module Workforce
  class CreditedMonth
    def self.credited?(employee, month_start)
      month_on = month_start.to_date.beginning_of_month
      payslip_exists?(employee, month_on) || skip_exists?(employee, month_on)
    end

    def self.payslip_exists?(employee, month_on)
      Payslip.joins(:payroll_run).exists?(
        company_id: employee.company_id,
        employee_id: employee.id,
        payroll_runs: { company_id: employee.company_id, month_on: }
      )
    end
    private_class_method :payslip_exists?

    def self.skip_exists?(employee, month_on)
      PayrollSkip.joins(:payroll_run).exists?(
        company_id: employee.company_id,
        employee_id: employee.id,
        payroll_runs: { company_id: employee.company_id, month_on: }
      )
    end
    private_class_method :skip_exists?
  end
end
