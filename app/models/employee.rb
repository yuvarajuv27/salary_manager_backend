# frozen_string_literal: true

class Employee < ApplicationRecord
  encrypts :bank_payload

  attribute :bank_details

  belongs_to :company
  belongs_to :entity
  has_many :salary_assignments, dependent: :destroy
  has_many :leave_days, dependent: :destroy
  has_many :payslips, dependent: :restrict_with_error
  has_many :payroll_skips, dependent: :destroy

  validates :name, :job_role, :department, :start_on, presence: true
  validates :bank_payload, presence: true
  validate :entity_belongs_to_company
  validate :end_on_on_or_after_start_on
  validate :bank_set_complete

  before_validation :sync_company_from_entity
  before_validation :apply_bank_details

  def bank_details=(hash)
    @bank_details_input = hash
  end

  def bank_details_hash
    JSON.parse(bank_payload)
  end

  def salary_on(date)
    salary_assignments
      .where(effective_on: ..date)
      .order(effective_on: :desc)
      .limit(1)
      .pick(:amount_minor)
  end

  def bank_details_for_api
    BankDetails.mask(bank_details_hash)
  rescue ActiveRecord::Encryption::Errors::Decryption, JSON::ParserError
    { "readable" => false }
  end

  private

  def apply_bank_details
    return if @bank_details_input.nil?
    return if entity.blank?

    document = BankDetails.encryptable_json(entity.country, @bank_details_input)
    self.bank_payload = document.to_json
  rescue BankDetails::InvalidSet => e
    errors.add(:bank_payload, e.message)
  end

  def sync_company_from_entity
    return unless entity

    self.company_id = entity.company_id
  end

  def entity_belongs_to_company
    return if entity.blank? || company_id.blank?
    return if entity.company_id == company_id

    errors.add(:entity_id, "must belong to the same company")
  end

  def end_on_on_or_after_start_on
    return if end_on.blank? || start_on.blank?
    return if end_on >= start_on

    errors.add(:end_on, "must be on or after the start date")
  end

  def bank_set_complete
    return if entity.blank? || bank_payload.blank?

    BankDetails.validate!(entity.country, bank_details_hash)
  rescue BankDetails::InvalidSet => e
    errors.add(:bank_payload, e.message)
  end
end
