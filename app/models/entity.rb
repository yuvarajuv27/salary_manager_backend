# frozen_string_literal: true

class Entity < ApplicationRecord
  belongs_to :company
  has_many :users, dependent: :restrict_with_error
  has_many :pay_rules, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :entity_credits, dependent: :restrict_with_error
  has_many :payslips, dependent: :restrict_with_error
  has_many :payroll_skips, dependent: :destroy
  has_many :currency_conversions, dependent: :restrict_with_error

  validates :name, presence: true
  validates :country, presence: true, inclusion: { in: Countries.all }
  validates :currency, presence: true

  before_validation :set_currency_from_country, on: :create

  private

  def set_currency_from_country
    return unless country.present? && Countries.valid?(country)

    self.currency = Countries.currency_for(country)
  end
end
