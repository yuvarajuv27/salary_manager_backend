# frozen_string_literal: true

class EmployeesController < ApplicationController
  before_action :require_authentication
  before_action :set_entity
  before_action :set_employee!, only: %i[show update destroy]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [[params.fetch(:per_page, 50).to_i, 1].max, 100].min
    scope = @entity.employees.order(:id)
    if params[:q].present?
      scope = scope.where("name ILIKE ?", "%#{Employee.sanitize_sql_like(params[:q].to_s.strip)}%")
    end

    total = scope.count
    employees = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      employees: employees.map { |employee| employee_json(employee) },
      page:,
      per_page:,
      total:,
      total_pages: (total.to_f / per_page).ceil
    }
  end

  def show
    render json: employee_json(@employee)
  end

  def create
    employee = @entity.employees.build(employee_assignable_params)
    employee.company = current_company

    if employee.save
      render json: employee_json(employee), status: :created
    else
      render json: { errors: validation_errors(employee) }, status: :unprocessable_content
    end
  end

  def update
    @employee.assign_attributes(employee_assignable_params.except(:bank_details))
    @employee.bank_details = employee_assignable_params[:bank_details] if employee_assignable_params.key?(:bank_details)

    if @employee.save
      render json: employee_json(@employee)
    else
      render json: { errors: validation_errors(@employee) }, status: :unprocessable_content
    end
  end

  def destroy
    if Workforce::PayslipGuard.employee_has_payslip?(@employee)
      return render json: { errors: { base: ["employee has a payslip"] } },
                    status: :unprocessable_content
    end

    @employee.destroy!
    head :no_content
  end

  private

  def set_entity
    @entity = find_entity!(params[:entity_id])
  end

  def set_employee!
    @employee = @entity.employees.find(params[:id])
  end

  def employee_assignable_params
    permitted = params.permit(:name, :job_role, :department, :start_on, :end_on)
    return permitted unless params.key?(:bank_details)

    permitted.merge(
      bank_details: params.require(:bank_details).permit(*Countries.bank_field_keys_for(@entity.country)).to_h
    )
  end
end
