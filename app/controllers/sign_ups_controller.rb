# frozen_string_literal: true

class SignUpsController < ApplicationController
  def create
    company = Company.new(company_params)
    company.pay_frequency = company.pay_frequency.presence || "monthly"
    company.payroll_day = company.payroll_day.presence || 31
    company.next_payroll_on = PayrollCalendar.next_future_payroll_on_for(company)

    user = company.users.build(
      name: user_params[:name],
      email: user_params[:email],
      password: user_params[:password],
      access_role: "admin",
      entity_id: nil
    )

    unless company.valid? && user.valid?
      render json: { errors: validation_errors(company, user) }, status: :unprocessable_content
      return
    end

    ActiveRecord::Base.transaction do
      company.save!
      user.save!
    end

    sign_in(user)
    render json: {
      user: session_payload(user)[:user],
      company: sign_up_company_payload(company)
    }, status: :created
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

  def user_params
    params.permit(:name, :email, :password)
  end
end
