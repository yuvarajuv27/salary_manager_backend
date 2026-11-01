# frozen_string_literal: true

class PayrollCalendar
  def self.payroll_on(month_start_date, payroll_day)
    month_start = month_start_date.beginning_of_month
    last_day_of_month = month_start.end_of_month.day
    day = [payroll_day, last_day_of_month].min
    Date.new(month_start.year, month_start.month, day)
  end

  def self.next_future_payroll_on(payroll_day, from_time: Time.now.utc)
    from_time = from_time.utc
    month_start = from_time.to_date.beginning_of_month

    loop do
      candidate = payroll_on(month_start, payroll_day)
      return candidate if candidate.beginning_of_day > from_time

      month_start = month_start.next_month.beginning_of_month
    end
  end

  def self.next_future_payroll_on_for(company, from_time: Time.now.utc)
    case company.pay_frequency
    when "weekly"
      next_weekday_after(company.pay_weekday, from_time:)
    when "biweekly"
      next_biweekly_after(company.pay_weekday, company.biweekly_anchor_on, from_time:)
    else
      next_future_payroll_on(company.payroll_day, from_time:)
    end
  end

  def self.period_bounds_for(company, payroll_on)
    case company.pay_frequency
    when "weekly"
      [payroll_on - 6, payroll_on]
    when "biweekly"
      [payroll_on - 13, payroll_on]
    else
      [payroll_on.beginning_of_month, payroll_on.end_of_month]
    end
  end

  def self.next_payroll_after(company, after_payroll_on)
    case company.pay_frequency
    when "weekly"
      after_payroll_on + 7
    when "biweekly"
      after_payroll_on + 14
    else
      payroll_on(after_payroll_on.next_month.beginning_of_month, company.payroll_day)
    end
  end

  def self.next_weekday_after(weekday, from_time: Time.now.utc)
    raise ArgumentError, "weekday required" if weekday.nil?

    from_time = from_time.utc
    date = from_time.to_date
    candidate = date + ((weekday - date.wday) % 7)
    candidate = candidate + 7 if candidate.beginning_of_day <= from_time
    candidate
  end

  def self.next_biweekly_after(weekday, anchor_on, from_time: Time.now.utc)
    raise ArgumentError, "weekday and anchor required" if weekday.nil? || anchor_on.nil?

    from_time = from_time.utc
    anchor = anchor_on.to_date
    # Align anchor to the configured weekday.
    anchor += (weekday - anchor.wday) % 7
    candidate = anchor
    while candidate.beginning_of_day <= from_time
      candidate += 14
    end
    candidate
  end
end
