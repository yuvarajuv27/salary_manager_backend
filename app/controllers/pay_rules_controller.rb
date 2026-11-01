# frozen_string_literal: true

class PayRulesController < ApplicationController
  before_action :require_authentication
  before_action :set_entity
  before_action :set_pay_rule!, only: %i[update destroy]

  def index
    render json: @entity.pay_rules.order(:position).map { |rule| pay_rule_json(rule) }
  end

  def create
    rule = @entity.pay_rules.build(pay_rule_params)
    rule.position = next_position if rule.position.nil?

    if rule.save
      render json: pay_rule_json(rule), status: :created
    else
      render json: { errors: validation_errors(rule) }, status: :unprocessable_content
    end
  end

  def update
    if @pay_rule.update(pay_rule_params)
      render json: pay_rule_json(@pay_rule)
    else
      render json: { errors: validation_errors(@pay_rule) }, status: :unprocessable_content
    end
  end

  def destroy
    @pay_rule.destroy!
    head :no_content
  end

  def order
    rule_ids = params.require(:rule_ids)
    rules_by_id = @entity.pay_rules.index_by(&:id)

    unless rule_ids.is_a?(Array) && rule_ids.map(&:to_i).sort == rules_by_id.keys.sort
      return render json: { errors: { rule_ids: ["must list every rule exactly once"] } },
                    status: :unprocessable_content
    end

    ActiveRecord::Base.transaction do
      rule_ids.each_with_index do |rule_id, position|
        rules_by_id.fetch(rule_id.to_i).update!(position:)
      end
    end

    index
  end

  def preview
    result = PayCalculator.call(
      rules: preview_rules,
      gross_minor: params.require(:gross_minor),
      currency: @entity.currency,
      mode: :preview
    )

    render json: preview_json(result)
  rescue PayCalculator::InvalidEarnings
    render json: { errors: { earnings: ["percents must sum to 100 when present"] } },
           status: :unprocessable_content
  end

  private

  def set_entity
    @entity = find_entity!(params[:entity_id])
  end

  def set_pay_rule!
    @pay_rule = @entity.pay_rules.find(params[:rule_id])
  end

  def next_position
    (@entity.pay_rules.maximum(:position) || -1) + 1
  end

  def pay_rule_params
    params.permit(
      :name, :position, :side, :kind, :percent, :amount_minor, :ceiling_minor
    )
  end

  def preview_rules
    params.require(:rules).map do |rule|
      source = rule.is_a?(ActionController::Parameters) ? rule : ActionController::Parameters.new(rule.to_h)
      source.permit(
        :name, :position, :side, :kind, :percent, :amount_minor, :ceiling_minor
      ).to_h.symbolize_keys
    end
  end

  def pay_rule_json(rule)
    {
      id: rule.id,
      entity_id: rule.entity_id,
      name: rule.name,
      position: rule.position,
      side: rule.side,
      kind: rule.kind,
      percent: formatted_percent(rule.percent),
      amount_minor: rule.amount_minor,
      ceiling_minor: rule.ceiling_minor
    }
  end

  def preview_json(result)
    {
      earnings: result.earnings.map { |line| line_json(line) },
      deductions: result.deductions.map { |line| line_json(line) },
      employer_contributions: result.employer_contributions.map { |line| line_json(line) },
      net_minor: result.net_minor,
      employer_cost_minor: result.employer_cost_minor
    }
  end

  def line_json(line)
    {
      position: line.position,
      name: line.name,
      side: line.side,
      kind: line.kind,
      percent: line.percent,
      amount_minor: line.amount_minor,
      ceiling_minor: line.ceiling_minor,
      computed_minor: line.computed_minor
    }
  end

  def formatted_percent(percent)
    return nil if percent.nil?

    format("%.4f", BigDecimal(percent.to_s))
  end
end
