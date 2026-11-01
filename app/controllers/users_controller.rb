# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :require_authentication
  before_action :require_admin!

  def index
    users = current_company.users.order(:id)
    render json: users.map { |user| user_json(user) }
  end

  def create
    user = current_company.users.build(user_params)

    if user.access_role == "admin"
      user.entity_id = nil
    elsif user.access_role == "hr" && user.entity_id.present?
      unless current_company.entities.exists?(id: user.entity_id)
        user.errors.add(:entity_id, "must belong to the company")
      end
    end

    if user.errors.empty? && user.save
      render json: user_json(user), status: :created
    else
      render json: { errors: validation_errors(user) }, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.permit(:name, :email, :password, :access_role, :entity_id)
  end
end
