# frozen_string_literal: true

class BankDetails
  class InvalidSet < StandardError; end

  FULL_MASK = "****"
  HOLDER_KEY = "account_holder_name"

  def self.validate!(country, hash)
    normalized = normalize_input(hash)
    keys = Countries.bank_field_keys_for(country)

    missing = keys.reject { |key| normalized[key].present? }
    raise InvalidSet, "missing bank fields: #{missing.join(', ')}" if missing.any?

    extras = normalized.keys - keys
    raise InvalidSet, "unexpected bank fields: #{extras.join(', ')}" if extras.any?

    true
  end

  def self.encryptable_json(country, hash)
    validate!(country, hash)
    keys = Countries.bank_field_keys_for(country)
    keys.index_with { |key| normalize_input(hash)[key].strip }
  end

  def self.mask(hash)
    normalize_input(hash).each_with_object({}) do |(key, value), masked|
      masked[key] = key == HOLDER_KEY ? value : mask_value(value)
    end
  end

  def self.mask_value(value)
    text = value.to_s
    return FULL_MASK if text.length < 4

    text[-4..]
  end
  private_class_method :mask_value

  def self.normalize_input(hash)
    hash.to_h.transform_keys(&:to_s)
  end
  private_class_method :normalize_input
end
