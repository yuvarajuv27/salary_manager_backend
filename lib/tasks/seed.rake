# frozen_string_literal: true

namespace :seed do
  desc "Load demo company: 10 entities × 1000 employees + open-month payslips (admin@seed.example / Password1!)"
  task load_demo: :environment do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = DemoSeedLoader.call
    company = result.fetch(:company)
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)

    puts "Demo seed complete in #{elapsed}s"
    puts "  Company:  #{company.legal_name} (id=#{company.id})"
    puts "  Entities: #{company.entities.count}"
    puts "  Employees: #{company.employees.count}"
    puts "  Payslips: #{Payslip.where(company_id: company.id).count}"
    puts "  Login:    admin@seed.example / Password1!"
  rescue DemoSeedLoader::AlreadySeeded => e
    abort e.message
  end
end
