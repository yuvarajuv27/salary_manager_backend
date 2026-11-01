# frozen_string_literal: true

class DemoSeedLoader
  class AlreadySeeded < StandardError; end

  ADMIN_EMAIL = "admin@seed.example"
  ADMIN_PASSWORD = "Password1!"
  COMPANY_NAME = "Seed Demo Co"
  DEFAULT_ENTITY_COUNT = 10
  DEFAULT_EMPLOYEES_PER_ENTITY = 1_000

  BANK_TEMPLATES = {
    "India" => ->(name) { { account_holder_name: name, account_number: "1234567890", ifsc: "HDFC0001234" } },
    "United States" => ->(name) { { account_holder_name: name, account_number: "1234567890", routing_number: "021000021" } },
    "United Kingdom" => ->(name) { { account_holder_name: name, account_number: "12345678", sort_code: "200000" } },
    "Canada" => lambda { |name|
      { account_holder_name: name, account_number: "1234567", institution_number: "001", transit_number: "12345" }
    },
    "Japan" => ->(name) { { account_holder_name: name, account_number: "1234567", bank_code: "0001", branch_code: "001" } },
    "Australia" => ->(name) { { account_holder_name: name, account_number: "12345678", bsb: "062000" } },
    "Singapore" => ->(name) { { account_holder_name: name, account_number: "1234567890", bank_code: "7171" } },
    "Portugal" => ->(name) { { account_holder_name: name, iban: "PT50000201231234567890154" } },
    "France" => ->(name) { { account_holder_name: name, iban: "FR1420041010050500013M02606" } }
  }.freeze

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(entity_count: DEFAULT_ENTITY_COUNT, employees_per_entity: DEFAULT_EMPLOYEES_PER_ENTITY)
    @entity_count = entity_count
    @employees_per_entity = employees_per_entity
  end

  def call
    raise AlreadySeeded, "#{ADMIN_EMAIL} already exists — aborting demo seed" if User.exists?(email: ADMIN_EMAIL)

    company = create_company_and_admin!
    create_entities!(company)
    credit_open_month!(company)
    { company: company.reload }
  end

  private

  attr_reader :entity_count, :employees_per_entity

  def create_company_and_admin!
    company = nil
    ActiveRecord::Base.transaction do
      company = Company.create!(
        legal_name: COMPANY_NAME,
        primary_currency: "USD",
        pay_frequency: "monthly",
        payroll_day: 31,
        next_payroll_on: PayrollCalendar.next_future_payroll_on(31)
      )
      User.create!(
        company:,
        name: "Seed Admin",
        email: ADMIN_EMAIL,
        password: ADMIN_PASSWORD,
        access_role: "admin"
      )
    end
    company
  end

  def create_entities!(company)
    countries = Countries.all
    entity_count.times do |index|
      country = countries[index % countries.length]
      ActiveRecord::Base.transaction do
        entity = company.entities.create!(
          name: "Entity #{index + 1} — #{country}",
          country:
        )
        create_pay_rules!(entity)
        create_workforce!(entity)
      end
    end
  end

  def create_pay_rules!(entity)
    entity.pay_rules.create!(
      [
        { name: "Base", side: "earning", kind: "percent", percent: BigDecimal("100"), position: 0 },
        { name: "Tax", side: "employee_deduction", kind: "percent", percent: BigDecimal("10"), position: 1 },
        {
          name: "Employer PF",
          side: "employer_contribution",
          kind: "percent",
          percent: BigDecimal("12"),
          position: 2
        }
      ]
    )
  end

  def create_workforce!(entity)
    open_month = entity.company.next_payroll_on.beginning_of_month
    start_on = open_month - 1.year
    now = Time.current

    employee_rows = Array.new(employees_per_entity) do |index|
      name = "Employee #{entity.id}-#{index + 1}"
      plaintext = BankDetails.encryptable_json(entity.country, bank_details_for(entity.country, name)).to_json
      {
        company_id: entity.company_id,
        entity_id: entity.id,
        name:,
        job_role: index.even? ? "Analyst" : "Engineer",
        department: index.even? ? "Finance" : "Engineering",
        start_on:,
        end_on: nil,
        bank_payload: ActiveRecord::Encryption.encryptor.encrypt(plaintext),
        created_at: now,
        updated_at: now
      }
    end

    inserted = Employee.insert_all!(employee_rows, returning: %w[id])
    employee_ids = inserted.rows.flatten

    salary_rows = employee_ids.each_with_index.map do |employee_id, index|
      {
        company_id: entity.company_id,
        employee_id:,
        effective_on: open_month,
        amount_minor: salary_minor_for(entity.currency, index),
        created_at: now,
        updated_at: now
      }
    end
    SalaryAssignment.insert_all!(salary_rows)
  end

  def bank_details_for(country, name)
    BANK_TEMPLATES.fetch(country).call(name)
  end

  def salary_minor_for(currency, index)
    base_major = 4_000 + (index % 50) * 100
    factor = 10**MoneyRounding::EXPONENTS.fetch(currency)
    base_major * factor
  end

  # Approximate FX vs USD for offline seed (not for production pricing).
  SEED_RATES_TO_USD = {
    "USD" => BigDecimal("1"),
    "INR" => BigDecimal("0.012"),
    "GBP" => BigDecimal("1.27"),
    "CAD" => BigDecimal("0.74"),
    "JPY" => BigDecimal("0.0067"),
    "AUD" => BigDecimal("0.66"),
    "SGD" => BigDecimal("0.74"),
    "EUR" => BigDecimal("1.08")
  }.freeze

  def credit_open_month!(company)
    payroll_on = company.next_payroll_on
    period_start_on, period_end_on = PayrollCalendar.period_bounds_for(company, payroll_on)
    run = company.payroll_runs.create!(
      month_on: period_start_on,
      payroll_on:,
      period_start_on:,
      period_end_on:,
      primary_currency: company.primary_currency,
      status: "processing"
    )

    previous_adapter = ActiveJob::Base.queue_adapter
    previous_client = CurrencyConversionJob.client
    ActiveJob::Base.queue_adapter = :inline
    CurrencyConversionJob.client = seed_fx_client

    company.entities.find_each do |entity|
      EntityCreditJob.perform_now(run.id, entity.id)
    end
  ensure
    CurrencyConversionJob.client = previous_client if previous_client
    ActiveJob::Base.queue_adapter = previous_adapter if previous_adapter
  end

  def seed_fx_client
    Class.new do
      def rate_on(date:, from:, to:)
        raise "seed FX only supports conversion to USD" unless to == "USD"

        rate = DemoSeedLoader::SEED_RATES_TO_USD.fetch(from)
        { rate:, date: }
      end
    end.new
  end
end
