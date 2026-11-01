# frozen_string_literal: true

class SalariesController < ApplicationController
  before_action :require_authentication
  before_action :set_entity
  before_action :set_employee!

  def correct
    assignment = SalaryWriter.correct!(@employee, amount_minor: params.require(:amount_minor).to_i)
    render json: salary_assignment_json(assignment)
  rescue SalaryWriter::CreditedMonth => e
    render json: { errors: { salary: [e.message] } }, status: :unprocessable_content
  rescue SalaryWriter::InvalidAmount => e
    render json: { errors: { amount_minor: [e.message] } }, status: :unprocessable_content
  end

  def revise
    assignment = SalaryWriter.revise!(@employee, amount_minor: params.require(:amount_minor).to_i)
    render json: salary_assignment_json(assignment)
  rescue SalaryWriter::InvalidAmount => e
    render json: { errors: { amount_minor: [e.message] } }, status: :unprocessable_content
  end

  private

  def set_entity
    @entity = find_entity!(params[:entity_id])
  end

  def set_employee!
    @employee = @entity.employees.find(params[:employee_id] || params[:id])
  end

  def salary_assignment_json(assignment)
    {
      employee_id: assignment.employee_id,
      effective_on: assignment.effective_on.iso8601,
      amount_minor: assignment.amount_minor
    }
  end
end
