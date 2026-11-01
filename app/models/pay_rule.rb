# frozen_string_literal: true

class PayRule < ApplicationRecord
  SIDES = %w[earning employee_deduction employer_contribution].freeze
  KINDS = %w[percent fixed].freeze
  DEDUCTION_SIDES = %w[employee_deduction employer_contribution].freeze

  belongs_to :company
  belongs_to :entity

  validates :name, presence: true
  validates :side, presence: true, inclusion: { in: SIDES }
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :entity_belongs_to_company
  validate :rule_shape

  before_validation :sync_company_from_entity

  private

  def sync_company_from_entity
    return unless entity

    self.company_id = entity.company_id
  end

  def entity_belongs_to_company
    return if entity.blank? || company_id.blank?
    return if entity.company_id == company_id

    errors.add(:entity_id, "must belong to the same company")
  end

  def rule_shape
    if side == "earning"
      validate_earning_shape
    elsif DEDUCTION_SIDES.include?(side)
      validate_deduction_or_employer_shape
    end
  end

  def validate_earning_shape
    errors.add(:kind, "must be percent for an earning") unless kind == "percent"
    validate_percent_range
    errors.add(:amount_minor, "must be blank for an earning") if amount_minor.present?
    errors.add(:ceiling_minor, "must be blank for an earning") if ceiling_minor.present?
  end

  def validate_deduction_or_employer_shape
    case kind
    when "percent"
      validate_percent_range
      errors.add(:amount_minor, "must be blank for a percent rule") if amount_minor.present?
      validate_ceiling_for_percent
    when "fixed"
      validate_fixed_amount
      errors.add(:percent, "must be blank for a fixed rule") if percent.present?
      errors.add(:ceiling_minor, "must be blank for a fixed rule") if ceiling_minor.present?
    end
  end

  def validate_percent_range
    return if percent.blank?

    if percent <= 0 || percent > 100
      errors.add(:percent, "must be greater than 0 and at most 100")
    end
  end

  def validate_ceiling_for_percent
    return if ceiling_minor.nil?

    if ceiling_minor <= 0
      errors.add(:ceiling_minor, "must be greater than 0 when present")
    end
  end

  def validate_fixed_amount
    if amount_minor.blank? || amount_minor <= 0
      errors.add(:amount_minor, "must be greater than 0 for a fixed rule")
    end
  end
end
