# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :require_authentication

  def show
    render json: profile_json(current_user)
  end

  def update
    user = current_user
    user.assign_attributes(profile_params.except(:password))
    if profile_params[:password].present?
      user.password = profile_params[:password]
    end

    if user.save
      render json: profile_json(user)
    else
      render json: { errors: validation_errors(user) }, status: :unprocessable_content
    end
  end

  private

  def profile_params
    params.permit(:name, :email, :password)
  end

  def profile_json(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      access_role: user.access_role,
      entity_id: user.entity_id
    }
  end
end
