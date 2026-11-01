# frozen_string_literal: true

class PayrollRunsController < ApplicationController
  before_action :require_authentication
  before_action :set_entity

  def index
    runs = PayrollRun
      .joins(:entity_credits)
      .where(entity_credits: { entity_id: @entity.id, status: "credited" })
      .order(:month_on)

    render json: runs.map { |run| payroll_run_summary_json(run) }
  end

  def show
    month_on = parse_month!(params[:month])
    run = PayrollRun
      .joins(:entity_credits)
      .find_by!(
        entity_credits: { entity_id: @entity.id, status: "credited" },
        month_on:
      )

    render json: payroll_run_month_json(run)
  end

  private

  def set_entity
    @entity = find_entity!(params[:entity_id])
  end

  def parse_month!(month_param)
    month_on =
      begin
        Date.iso8601(month_param.to_s).beginning_of_month
      rescue Date::Error
        Date.strptime(month_param.to_s, "%Y-%m").beginning_of_month
      end
    month_on
  rescue Date::Error, ArgumentError
    raise ActiveRecord::RecordNotFound
  end

  def payroll_run_summary_json(run)
    {
      month_on: run.month_on.iso8601,
      payroll_on: run.payroll_on.iso8601,
      status: run.status
    }
  end

  def payroll_run_month_json(run)
    payslips = run.payslips.where(entity_id: @entity.id).includes(:employee).order(:id)
    skips = run.payroll_skips.where(entity_id: @entity.id).includes(:employee).order(:id)

    entries = payslips.map { |payslip| month_payslip_entry_json(payslip) } +
              skips.map { |skip| month_skip_entry_json(skip) }

    payroll_run_summary_json(run).merge(entries: entries.sort_by { |entry| entry.fetch(:employee_name) })
  end

  def month_payslip_entry_json(payslip)
    {
      type: "payslip",
      payslip_id: payslip.id,
      employee_id: payslip.employee_id,
      employee_name: payslip.employee.name,
      gross_minor: payslip.gross_minor,
      net_minor: payslip.net_minor,
      employer_cost_minor: payslip.employer_cost_minor
    }
  end

  def month_skip_entry_json(skip)
    {
      type: "skip",
      employee_id: skip.employee_id,
      employee_name: skip.employee.name,
      reason: skip.reason
    }
  end
end
