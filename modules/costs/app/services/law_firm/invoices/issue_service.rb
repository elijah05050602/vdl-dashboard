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
    class IssueService
      attr_reader :user, :project, :config

      def initialize(user:, project:, config: BillingConfig.current)
        @user = user
        @project = project
        @config = config
      end

      def call(request) # rubocop:disable Metrics/AbcSize
        return failure(request, :invoice_unauthorized) unless user.allowed_in_project?(:issue_law_firm_invoices, project)
        return failure(request, :invoice_details_missing, fields: missing_details) unless config.invoice.ready_to_issue?
        return ServiceResult.failure(result: request, errors: request.errors) unless request.valid?

        Invoice.transaction do
          # Serial numbers must be gapless and never reused, and an entry may
          # only be billed once, so issuing runs one at a time.
          Invoice.connection.execute("LOCK TABLE #{Invoice.quoted_table_name} IN SHARE ROW EXCLUSIVE MODE")

          statement = build_statement(request)
          return failure(request, :invoice_nothing_to_bill) if statement.empty?

          serial = next_serial
          return failure(request, :invoice_series_exhausted) if beyond_series?(serial)

          invoice = Invoice.create!(statement.invoice_attributes.merge(
                                      serial:,
                                      number: config.invoice.format_number(serial),
                                      issued_on: user.today,
                                      client_name: request.client_name.strip,
                                      client_address: request.client_address.strip,
                                      client_tin: request.client_tin.presence&.strip,
                                      issued_by: user
                                    ))
          ServiceResult.success(result: invoice)
        end
      end

      def build_statement(request)
        Statement.new(project:,
                      period_from: request.period_from,
                      period_to: request.period_to,
                      ewt_rate: request.effective_ewt_rate,
                      config:)
      end

      private

      def next_serial
        [Invoice.maximum(:serial).to_i + 1, config.invoice.series_start].max
      end

      def beyond_series?(serial)
        config.invoice.series_end.present? && serial > config.invoice.series_end
      end

      def missing_details
        config.invoice.missing_details.map { |key| I18n.t("law_firm_invoices.settings.#{key}") }.join(", ")
      end

      def failure(request, key, **)
        request.errors.add(:base, key, **)
        ServiceResult.failure(result: request, errors: request.errors)
      end
    end
  end
end
