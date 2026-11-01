# frozen_string_literal: true

class FrankfurterClient
  include HTTParty

  base_uri "https://api.frankfurter.app"

  Rate = Data.define(:date, :rate)

  def rate_on(date:, from:, to:)
    response = self.class.get("/#{date.iso8601}", query: { from:, to: })
    raise Error, "Frankfurter returned #{response.code}" unless response.success?

    body = response.parsed_response
    rate = body.fetch("rates").fetch(to)

    Rate.new(date: Date.iso8601(body.fetch("date")), rate: BigDecimal(rate.to_s))
  rescue KeyError, Date::Error => e
    raise Error, e.message
  end

  Error = Class.new(StandardError)
end
