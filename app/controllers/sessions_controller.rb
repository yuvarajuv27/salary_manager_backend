# frozen_string_literal: true

class SessionsController < ApplicationController
  before_action :require_authentication, only: %i[show destroy]

  def show
    render_session(current_user)
  end

  def create
    user = User.find_by(email: session_params[:email])

    if user&.authenticate(session_params[:password])
      sign_in(user)
      render_session(user)
    else
      head :unauthorized
    end
  end

  def destroy
    sign_out_user
    head :no_content
  end

  private

  def session_params
    params.permit(:email, :password)
  end
end
