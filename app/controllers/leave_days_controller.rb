# frozen_string_literal: true

class LeaveDaysController < ApplicationController
  before_action :require_authentication
  before_action :set_entity
  before_action :set_employee!

  def index
    leave_days = @employee.leave_days.order(:leave_on)
    render json: leave_days.map { |leave_day| leave_day_json(leave_day) }
  end

  def create
    leave_day = @employee.leave_days.build(leave_day_params)
    leave_day.company = current_company

    if leave_day.save
      render json: leave_day_json(leave_day), status: :created
    else
      render json: { errors: validation_errors(leave_day) }, status: :unprocessable_content
    end
  end

  def destroy
    leave_day = @employee.leave_days.find_by!(leave_on: Date.iso8601(params[:date]))

    if leave_day.destroy
      head :no_content
    else
      render json: { errors: validation_errors(leave_day) }, status: :unprocessable_content
    end
  end

  private

  def set_entity
    @entity = find_entity!(params[:entity_id])
  end

  def set_employee!
    @employee = @entity.employees.find(params[:employee_id])
  end

  def leave_day_params
    params.permit(:leave_on)
  end

  def leave_day_json(leave_day)
    { leave_on: leave_day.leave_on.iso8601 }
  end
end
