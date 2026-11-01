# frozen_string_literal: true

class CurrencyConversion < ApplicationRecord
  STATUSES = %w[stored pending].freeze

  belongs_to :company
  belongs_to :payroll_run
  belongs_to :entity

  validates :status, :primary_currency, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :primary_currency, inclusion: { in: Company::PRIMARY_CURRENCIES }
  validates :entity_id, uniqueness: { scope: :payroll_run_id }
  validate :payroll_run_belongs_to_company
  validate :entity_belongs_to_company
  validate :stored_shape

  before_validation :sync_company_from_payroll_run

  private

  def sync_company_from_payroll_run
    return unless payroll_run

    self.company_id = payroll_run.company_id
  end

  def payroll_run_belongs_to_company
    return if payroll_run.blank? || company_id.blank?
    return if payroll_run.company_id == company_id

    errors.add(:payroll_run_id, "must belong to the same company")
  end

  def entity_belongs_to_company
    return if entity.blank? || company_id.blank?
    return if entity.company_id == company_id

    errors.add(:entity_id, "must belong to the same company")
  end

  def stored_shape
    case status
    when "stored"
      %i[rate rate_on gross_minor net_minor employer_cost_minor].each do |attr|
        errors.add(attr, "must be present when stored") if self[attr].nil?
      end
    when "pending"
      %i[rate rate_on gross_minor net_minor employer_cost_minor].each do |attr|
        errors.add(attr, "must be blank when pending") if self[attr].present?
      end
    end
  end
end
