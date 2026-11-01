unless Rails.env.test?
  primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
  deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
  key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

  if primary_key.present? && deterministic_key.present? && key_derivation_salt.present?
    Rails.application.config.active_record.encryption.primary_key = primary_key
    Rails.application.config.active_record.encryption.deterministic_key = deterministic_key
    Rails.application.config.active_record.encryption.key_derivation_salt = key_derivation_salt
  end
end
