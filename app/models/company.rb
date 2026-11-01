# frozen_string_literal: true

class Company < ApplicationRecord
  PRIMARY_CURRENCIES = %w[INR USD GBP CAD JPY AUD SGD EUR].freeze
  PAY_FREQUENCIES = %w[monthly weekly biweekly].freeze

  has_many :users, dependent: :restrict_with_error

  validates :legal_name, presence: true
  validates :primary_currency, presence: true, inclusion: { in: PRIMARY_CURRENCIES }
  validates :pay_frequency, presence: true, inclusion: { in: PAY_FREQUENCIES }
  validates :next_payroll_on, presence: true
  validate :schedule_fields_match_frequency

  private

  def schedule_fields_match_frequency
    case pay_frequency
    when "monthly"
      if payroll_day.blank? || !(1..31).cover?(payroll_day.to_i)
        errors.add(:payroll_day, "must be between 1 and 31 for monthly payroll")
      end
    when "weekly"
      errors.add(:pay_weekday, "must be present for weekly payroll") if pay_weekday.nil?
      errors.add(:pay_weekday, "is not a valid weekday") unless pay_weekday.nil? || (0..6).cover?(pay_weekday)
    when "biweekly"
      errors.add(:pay_weekday, "must be present for biweekly payroll") if pay_weekday.nil?
      errors.add(:pay_weekday, "is not a valid weekday") unless pay_weekday.nil? || (0..6).cover?(pay_weekday)
      errors.add(:biweekly_anchor_on, "must be present for biweekly payroll") if biweekly_anchor_on.blank?
    end
  end
end
