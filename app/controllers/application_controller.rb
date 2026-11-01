class ApplicationController < ActionController::API
  include ActionController::Cookies

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def current_company
    current_user&.company
  end

  def require_authentication
    head :unauthorized unless current_user
  end

  def record_not_found
    head :not_found
  end

  def sign_in(user)
    session[:user_id] = user.id
  end

  def sign_out_user
    session.delete(:user_id)
    @current_user = nil
  end

  def render_session(user, status: :ok)
    render json: session_payload(user), status: status
  end

  def session_payload(user)
    company = user.company
    {
      user: user_json(user),
      company: {
        id: company.id,
        has_entity: false
      }
    }
  end

  def sign_up_company_payload(company)
    company_json(company).merge(has_entity: false)
  end

  def company_json(company)
    {
      id: company.id,
      legal_name: company.legal_name,
      primary_currency: company.primary_currency,
      pay_frequency: company.pay_frequency,
      payroll_day: company.payroll_day,
      pay_weekday: company.pay_weekday,
      biweekly_anchor_on: company.biweekly_anchor_on&.iso8601,
      next_payroll_on: company.next_payroll_on.iso8601
    }
  end

  def user_json(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      access_role: user.access_role,
      entity_id: user.entity_id
    }
  end

  def validation_errors(*records)
    records.each_with_object({}) do |record, merged|
      record.errors.messages.each do |attribute, messages|
        merged[attribute.to_s] ||= messages
      end
    end
  end
end
