# frozen_string_literal: true

class PayrollRun < ApplicationRecord
  STATUSES = %w[processing credited].freeze

  belongs_to :company
  has_many :entity_credits, dependent: :restrict_with_error
  has_many :payslips, dependent: :restrict_with_error
  has_many :payroll_skips, dependent: :restrict_with_error
  has_many :currency_conversions, dependent: :restrict_with_error

  validates :month_on, :payroll_on, :primary_currency, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :primary_currency, inclusion: { in: Company::PRIMARY_CURRENCIES }
  validates :month_on, uniqueness: { scope: :company_id }
end
