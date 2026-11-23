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

module BasicData
  module Costs
    # Idempotent: on an existing installation `db:seed` adds only what is missing.
    class LawFirmBillingSeeder < ::Seeder
      REPORT_COLUMNS = %w[tyear tmonth].freeze
      HOURS_UNIT = -1
      MONEY_UNIT = 0

      def seed_data!
        seed_default_project_modules
        seed_billing_roles
        seed_non_billable_activities
        seed_expense_types
        seed_reports
      end

      private

      def config
        @config ||= ::LawFirm::BillingConfig.current
      end

      def seed_default_project_modules
        missing_modules = config.default_project_modules - Setting.default_projects_modules
        return if missing_modules.empty? || !writable_setting?(:default_projects_modules)

        Setting.default_projects_modules = Setting.default_projects_modules + missing_modules
      end

      def writable_setting?(name)
        Settings::Definition[name].writable?
      end

      def seed_billing_roles
        base_permissions = member_role&.permissions || []
        position = Role.maximum(:position).to_i

        config.billing_roles.each do |role|
          existing = ProjectRole.find_by(name: role[:name])
          if existing
            grant_invoice_permissions(existing, role)
            next
          end

          ProjectRole.create!(name: role[:name],
                              position: position += 1,
                              permissions: known_permissions(base_permissions + role[:permissions]))
        end
      end

      # Invoices came after the billing roles, so partners on an existing
      # installation are given the invoice permissions their preset includes.
      def grant_invoice_permissions(existing, role)
        missing = known_permissions(role[:permissions] & ::LawFirm::BillingConfig::INVOICE_PERMISSIONS) - existing.permissions
        return if missing.empty?

        existing.add_permission!(*missing)
        existing.save!
      end

      def member_role
        seed_data.find_reference(:default_role_member, default: nil)
      end

      def known_permissions(names)
        names.map(&:to_sym).uniq.select { |name| OpenProject::AccessControl.permission(name) }
      end

      def seed_non_billable_activities
        position = TimeEntryActivity.maximum(:position).to_i

        config.non_billable_activities.each do |name|
          next if TimeEntryActivity.exists?(name:)

          TimeEntryActivity.create!(name:, position: position += 1, active: true)
        end
      end

      def seed_expense_types
        config.expense_types.each do |expense|
          next if CostType.exists?(name: expense[:name])

          cost_type = CostType.create!(name: expense[:name],
                                       unit: expense[:unit],
                                       unit_plural: expense[:unit_plural],
                                       default: expense[:default].present? && !CostType.exists?(default: true),
                                       for_all_projects: true)
          CostRate.create!(cost_type:, rate: expense[:rate], valid_from: Date.current)
        end
      end

      def seed_reports
        non_billable_ids = TimeEntryActivity.where(name: config.non_billable_activities).pluck(:id).map(&:to_s)
        return if non_billable_ids.empty?

        seed_report("Billable hours by matter", rows: %w[project_id user_id], unit: HOURS_UNIT,
                                                filter: ["activity_id", "!", non_billable_ids])
        seed_report("Billable amounts by matter (before tax)", rows: %w[project_id user_id], unit: MONEY_UNIT,
                                                               filter: ["activity_id", "!", non_billable_ids])
        seed_report("Non-billable time by person", rows: %w[user_id activity_id], unit: HOURS_UNIT,
                                                   filter: ["activity_id", "=", non_billable_ids])
      end

      def seed_report(name, rows:, unit:, filter:)
        return if CostReport.public_views.exists?(name:, project_id: nil)

        report = CostReport.new(name:, public: true, query: CostReportQuery.new(name:))
        report.query.where(*filter)
        report.apply_pivot_configuration(rows:, columns: REPORT_COLUMNS)
        report.unit_id = unit
        report.save!
      end
    end
  end
end
