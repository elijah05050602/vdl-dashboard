# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module LawFirm
  module Invoices
    # Collects a matter's billable time, fees and disbursements for a period
    # that are not on an active invoice yet, and works out the BIR totals.
    # Amounts logged in OpenProject exclude VAT.
    class Statement
      PESO_UNITS = %w[peso pesos php ₱].freeze

      attr_reader :project, :period_from, :period_to, :ewt_rate, :config

      def initialize(project:, period_from:, period_to:, ewt_rate: nil, config: BillingConfig.current)
        @project = project
        @period_from = period_from
        @period_to = period_to
        @ewt_rate = ewt_rate
        @config = config
      end

      def empty?
        time_entries.empty? && cost_entries.empty?
      end

      def unpriced_entry_count
        time_entries.count { |entry| entry.real_costs.to_d.zero? }
      end

      def lines
        @lines ||= time_lines + cost_lines
      end

      def details
        @details ||= time_entries.map { |entry| time_detail(entry) } + cost_entries.map { |entry| cost_detail(entry) }
      end

      def totals # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity
        @totals ||= begin
          vat_rate = config.vat_registered? ? config.vat_rate : nil
          subtotal = sum(lines)
          vatable = vat_rate ? sum(lines.select { |line| line[:vatable] }) : 0.to_d
          exempt = vat_rate ? subtotal - vatable : 0.to_d
          vat_amount = vat_rate ? round(vatable * vat_rate) : 0.to_d
          total = subtotal + vat_amount
          ewt_base = sum(lines.reject { |line| line[:kind] == "disbursement" })
          ewt_amount = ewt_rate ? round(ewt_base * ewt_rate) : 0.to_d

          {
            vatable_sales: vatable, vat_exempt_sales: exempt, zero_rated_sales: 0.to_d,
            vat_rate:, vat_amount:, total_amount: total,
            ewt_base:, ewt_rate:, ewt_amount:, amount_due: total - ewt_amount
          }
        end
      end

      def invoice_attributes # rubocop:disable Metrics/AbcSize
        totals.merge(project:, period_from:, period_to:,
                     lines: lines.map { |line| serialize(line) },
                     details: details.map { |detail| serialize(detail) },
                     seller: config.invoice.seller_snapshot,
                     time_entry_ids: time_entries.map(&:id),
                     cost_entry_ids: cost_entries.map(&:id))
      end

      def time_entries
        @time_entries ||= TimeEntry
          .where(project:, ongoing: false)
          .spent_between(period_from, period_to)
          .where.not(activity_id: non_billable_activity_ids)
          .where.not(id: Invoice.invoiced_entry_ids(project, :time_entry_ids))
          .includes(:user, :activity)
          .order(:spent_on, :id)
          .to_a
      end

      def cost_entries
        @cost_entries ||= CostEntry
          .where(project:, spent_on: period_from..period_to)
          .where.not(id: Invoice.invoiced_entry_ids(project, :cost_entry_ids))
          .includes(:cost_type, :user)
          .order(:spent_on, :id)
          .to_a
      end

      private

      def non_billable_activity_ids
        TimeEntryActivity.where(name: config.non_billable_activities).pluck(:id)
      end

      def time_lines # rubocop:disable Metrics/AbcSize
        time_entries.group_by(&:user).map do |user, entries|
          hours = entries.sum { |entry| entry.hours.to_d }
          amount = round(entries.sum { |entry| entry.real_costs.to_d })
          {
            kind: "time",
            description: I18n.t("law_firm_invoices.pdf.professional_services", name: user&.name),
            quantity: hours.round(2), unit: I18n.t("law_firm_invoices.pdf.hours_unit"),
            unit_cost: hours.zero? ? 0.to_d : round(amount / hours), amount:,
            vatable: true
          }
        end
      end

      def cost_lines
        lines = cost_entries.group_by(&:cost_type).map { |cost_type, entries| cost_line(cost_type, entries) }
        lines.sort_by { |line| line[:kind] == "fee" ? 0 : 1 }
      end

      def cost_line(cost_type, entries)
        kind = disbursement?(cost_type) ? "disbursement" : "fee"
        amount = round(entries.sum { |entry| entry.real_costs.to_d })
        quantity, unit = cost_quantity(cost_type, entries)

        {
          kind:, description: cost_type&.name.to_s, quantity:, unit:,
          unit_cost: quantity.zero? ? 0.to_d : round(amount / quantity), amount:,
          vatable: kind == "fee" || config.invoice.disbursements_vatable?
        }
      end

      def cost_quantity(cost_type, entries)
        if cost_type.nil? || PESO_UNITS.include?(cost_type.unit.to_s.downcase)
          [1.to_d, ""]
        else
          units = entries.sum { |entry| entry.units.to_d }
          [units, units == 1 ? cost_type.unit : cost_type.unit_plural]
        end
      end

      def disbursement?(cost_type)
        config.disbursement_type_names.include?(cost_type&.name)
      end

      def time_detail(entry)
        {
          kind: "time", date: entry.spent_on, person: entry.user&.name,
          activity: entry.activity&.name, description: entry.comments.to_s,
          quantity: entry.hours.to_d.round(2), amount: round(entry.real_costs.to_d)
        }
      end

      def cost_detail(entry)
        {
          kind: disbursement?(entry.cost_type) ? "disbursement" : "fee", date: entry.spent_on,
          person: entry.user&.name, activity: entry.cost_type&.name, description: entry.comments.to_s,
          quantity: entry.units.to_d, amount: round(entry.real_costs.to_d)
        }
      end

      def sum(lines)
        lines.sum(0.to_d) { |line| line[:amount] }
      end

      def round(value)
        value.to_d.round(2, BigDecimal::ROUND_HALF_UP)
      end

      def serialize(hash)
        hash.transform_keys(&:to_s).transform_values do |value|
          case value
          when BigDecimal then value.to_s("F")
          when Date then value.iso8601
          else value
          end
        end
      end
    end
  end
end
