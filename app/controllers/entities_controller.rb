# frozen_string_literal: true

class EntitiesController < ApplicationController
  before_action :require_authentication
  before_action :require_admin!, only: %i[create update destroy]

  def index
    entities =
      if current_user.access_role == "hr"
        current_company.entities.where(id: current_user.entity_id)
      else
        current_company.entities.order(:id)
      end

    render json: entities.map { |entity| entity_json(entity) }
  end

  def show
    entity = find_entity!(params[:id])
    render json: entity_json(entity)
  end

  def create
    company = current_company
    first_entity = !company.entities.exists?
    entity = company.entities.build(entity_params)

    ActiveRecord::Base.transaction do
      entity.save!
      if first_entity && company.next_payroll_on < Time.now.utc.to_date
        company.update!(
          next_payroll_on: PayrollCalendar.next_future_payroll_on_for(company)
        )
      end
    end

    render json: entity_json(entity), status: :created
  rescue ActiveRecord::RecordInvalid
    render json: { errors: validation_errors(entity) }, status: :unprocessable_content
  end

  def update
    entity = find_entity!(params[:id])
    entity.assign_attributes(entity_params)
    entity.currency = Countries.currency_for(entity.country) if entity.country_changed?

    if entity.save
      render json: entity_json(entity)
    else
      render json: { errors: validation_errors(entity) }, status: :unprocessable_content
    end
  end

  def destroy
    entity = find_entity!(params[:id])
    entity.destroy!
    head :no_content
  end

  private

  def entity_params
    params.permit(:name, :country)
  end
end
