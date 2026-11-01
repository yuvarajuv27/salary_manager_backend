# frozen_string_literal: true

module Workforce
  class EntityCountryChange
    class NotAllowed < StandardError; end
    class IncompleteBanks < StandardError; end

    def self.call!(entity, country:, employee_banks:)
      raise NotAllowed, "country is locked after the first credited payslip" if PayslipGuard.entity_has_payslip?(entity)

      new_country = country.to_s
      employees = entity.employees.order(:id).to_a
      banks_by_id = index_banks(employee_banks)

      validate_bank_coverage!(employees, banks_by_id)

      ActiveRecord::Base.transaction do
        entity.update!(country: new_country, currency: Countries.currency_for(new_country))
        employees.each do |employee|
          employee.bank_details = banks_by_id.fetch(employee.id)
          employee.save!
        end
      end

      entity
    end

    def self.index_banks(employee_banks)
      Array(employee_banks).each_with_object({}) do |entry, indexed|
        source = entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry.to_h
        employee_id = source["employee_id"] || source[:employee_id]
        bank_details = source["bank_details"] || source[:bank_details]
        indexed[employee_id.to_i] = bank_details if employee_id.present?
      end
    end
    private_class_method :index_banks

    def self.validate_bank_coverage!(employees, banks_by_id)
      return if employees.empty?

      employee_ids = employees.map(&:id)
      missing = employee_ids.reject { |id| banks_by_id.key?(id) }
      extra = banks_by_id.keys - employee_ids
      raise IncompleteBanks, "every employee needs bank details for the new country" if missing.any? || extra.any?
    end
    private_class_method :validate_bank_coverage!
  end
end
