# frozen_string_literal: true

class AnalyticsController < ApplicationController
  before_action :require_authentication
  before_action :require_admin!, only: :account

  def entity
    entity = find_entity!(params[:id])
    render json: serialize_entity(Analytics::EntityAnalytics.call(entity:))
  end

  def account
    render json: serialize_account(Analytics::AccountAnalytics.call(company: current_company))
  end

  private

  def serialize_entity(payload)
    {
      currency: payload[:currency],
      latest: serialize_month_snapshot(payload[:latest]),
      series: payload[:series].map { |row| serialize_series_row(row) },
      rule_totals: payload[:rule_totals],
      empty: payload[:empty]
    }
  end

  def serialize_account(payload)
    serialize_entity(payload).merge(
      employer_cost_by_entity: payload[:employer_cost_by_entity],
      pending_entity_names: payload[:pending_entity_names]
    )
  end

  def serialize_month_snapshot(snapshot)
    return nil unless snapshot

    {
      month_on: snapshot[:month_on].iso8601,
      headcount: snapshot[:headcount],
      gross_minor: snapshot[:gross_minor],
      net_minor: snapshot[:net_minor],
      employer_cost_minor: snapshot[:employer_cost_minor]
    }
  end

  def serialize_series_row(row)
    {
      month_on: row[:month_on].iso8601,
      gross_minor: row[:gross_minor],
      net_minor: row[:net_minor],
      employer_cost_minor: row[:employer_cost_minor]
    }
  end
end
