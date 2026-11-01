# frozen_string_literal: true

class CompaniesController < ApplicationController
  before_action :require_authentication
  before_action :require_admin!

  def show
    render json: company_json(current_company)
  end

  def update
    company = current_company
    company.assign_attributes(company_params)

    if company.save
      render json: company_json(company)
    else
      render json: { errors: validation_errors(company) }, status: :unprocessable_content
    end
  end

  private

  def company_params
    params.permit(
      :legal_name,
      :primary_currency,
      :pay_frequency,
      :payroll_day,
      :pay_weekday,
      :biweekly_anchor_on
    )
  end
end
