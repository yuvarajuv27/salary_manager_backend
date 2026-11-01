# frozen_string_literal: true

class PayslipsController < ApplicationController
  before_action :require_authentication
  before_action :set_entity
  before_action :set_payslip!

  def show
    render json: payslip_json(@payslip)
  end

  private

  def set_entity
    @entity = find_entity!(params[:entity_id])
  end

  def set_payslip!
    @payslip = @entity.payslips.includes(:employee, :payroll_run).find(params[:id])
  end

  def payslip_json(payslip)
    employee = payslip.employee
    {
      id: payslip.id,
      employee_id: employee.id,
      employee_name: employee.name,
      job_role: employee.job_role,
      department: employee.department,
      month_on: payslip.payroll_run.month_on.iso8601,
      payroll_on: payslip.payroll_run.payroll_on.iso8601,
      currency: payslip.currency,
      payable_days: payslip.payable_days,
      leave_days_count: payslip.leave_days_count,
      outside_days: payslip.outside_days,
      salary_minor: payslip.salary_minor,
      gross_minor: payslip.gross_minor,
      net_minor: payslip.net_minor,
      employer_cost_minor: payslip.employer_cost_minor,
      lines: payslip.lines
    }
  end
end
