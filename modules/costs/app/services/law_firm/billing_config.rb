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
  class BillingConfig
    PATH = Rails.root.join("config/law_firm_billing.yml")

    TIMEKEEPER_PERMISSIONS = %i[
      view_own_time_entries
      log_own_time
      edit_own_time_entries
      view_own_hourly_rate
      view_cost_rates
      log_own_costs
      edit_own_cost_entries
      view_own_cost_entries
      view_budgets
      save_private_cost_reports
    ].freeze

    PARTNER_PERMISSIONS = (TIMEKEEPER_PERMISSIONS + %i[
      view_time_entries
      log_time
      edit_time_entries
      view_hourly_rates
      edit_hourly_rates
      view_cost_entries
      log_costs
      edit_cost_entries
      edit_budgets
      save_cost_reports
    ]).freeze

    PERMISSION_PRESETS = {
      "timekeeper" => TIMEKEEPER_PERMISSIONS,
      "partner" => PARTNER_PERMISSIONS
    }.freeze

    class << self
      def current
        new(load_data)
      end

      private

      def load_data
        return {} unless PATH.exist?

        YAML.safe_load_file(PATH, permitted_classes: [Symbol]) || {}
      end
    end

    def initialize(data)
      @data = data.deep_stringify_keys
    end

    def currency
      @data["currency"].presence
    end

    def default_project_modules
      Array(@data["default_project_modules"]).map(&:to_s)
    end

    def billing_roles
      Array(@data["billing_roles"]).map do |role|
        {
          name: role["name"].to_s,
          hourly_rate: role["hourly_rate"],
          permissions: PERMISSION_PRESETS.fetch(role["permissions"].to_s, TIMEKEEPER_PERMISSIONS)
        }
      end
    end

    def non_billable_activities
      Array(@data["non_billable_activities"]).map(&:to_s)
    end

    def expense_types
      Array(@data["expense_types"]).map(&:symbolize_keys)
    end

    def hourly_rate_for(role_names)
      wanted = role_names.map { |name| name.to_s.downcase }

      billing_roles
        .select { |role| wanted.include?(role[:name].downcase) && role[:hourly_rate].present? }
        .map { |role| BigDecimal(role[:hourly_rate].to_s) }
        .max
    end
  end
end
