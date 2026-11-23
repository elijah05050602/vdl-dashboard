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
  # A matter's receivables: what is owed on its invoices, payments and BIR
  # Form 2307s received, the retainer, unbilled work and the billing terms.
  class BillingController < ApplicationController
    menu_item :law_firm_billing
    helper LawFirm::BillingHelper

    before_action :find_project_by_project_id
    before_action :authorize

    def show
      @receivables = Receivable.for_projects(@project)
      @retainer_entries = RetainerEntry.where(project: @project).newest_first.includes(:recorded_by)
      @retainer_balance = RetainerEntry.balance(@project)
      @terms = EngagementTerms.for(@project)
      @payments = Payment.where(invoice_id: @receivables.map { it.invoice.id }).newest_first.group_by(&:invoice_id)
      @unbilled = UnbilledEntries.new(@project)
      @can_manage = allowed?(:manage_law_firm_receivables)
    end

    def unbilled
      @unbilled = UnbilledEntries.new(@project)
      @write_downs = WriteDown.where(project: @project).newest_first.includes(:user, :entry)
      @can_write_down = allowed?(:write_down_law_firm_entries)
    end

    def terms
      @terms = EngagementTerms.for(@project) || EngagementTerms.new(project: @project)
      @roles = billing_role_names
      @can_manage = allowed?(:manage_law_firm_receivables)
    end

    def update_terms
      @terms = EngagementTerms.for(@project) || EngagementTerms.new(project: @project)
      @terms.assign_attributes(terms_params)

      if @terms.save
        changed = ApplyEngagementRatesService.new(@project).call
        flash[:notice] = t("law_firm_billing.terms.saved", count: changed)
        redirect_to terms_project_billing_path(@project)
      else
        @roles = billing_role_names
        @can_manage = true
        render :terms, status: :unprocessable_entity
      end
    end

    def create_payment
      invoice = Invoice.active.find_by!(project: @project, id: params.dig(:payment, :invoice_id))
      call = Receivables::RecordPaymentService.new(user: User.current, invoice:).call(payment_params)
      respond_with(call, t("law_firm_billing.payment_recorded", number: invoice.number))
    end

    def create_certificate
      invoice = Invoice.active.find_by!(project: @project, id: params.dig(:certificate, :invoice_id))
      certificate = WithholdingCertificate.new(certificate_params.merge(invoice:, recorded_by: User.current))
      respond_with(record_result(certificate), t("law_firm_billing.certificate_recorded", number: invoice.number))
    end

    def create_retainer_entry
      entry = RetainerEntry.new(retainer_params.merge(project: @project, recorded_by: User.current))
      respond_with(record_result(entry), t("law_firm_billing.retainer_recorded"))
    end

    def create_write_down
      entry = find_unbilled_entry
      call = Receivables::WriteDownService.new(user: User.current, project: @project)
                                          .call(entry:, new_amount: params.dig(:write_down, :new_amount),
                                                reason: params.dig(:write_down, :reason).to_s.strip)
      respond_with(call, t("law_firm_billing.written_down"), back: unbilled_project_billing_path(@project))
    end

    private

    def allowed?(permission)
      User.current.allowed_in_project?(permission, @project)
    end

    def billing_role_names
      (BillingConfig.current.billing_roles.pluck(:name) + @terms.role_rates.keys).uniq
    end

    def record_result(record)
      if record.save
        ServiceResult.success(result: record)
      else
        ServiceResult.failure(result: record, errors: record.errors)
      end
    end

    def respond_with(call, notice, back: project_billing_path(@project))
      if call.success?
        flash[:notice] = notice
      else
        flash[:error] = call.errors.full_messages.to_sentence
      end
      redirect_to back
    end

    def find_unbilled_entry
      scope = params.dig(:write_down, :entry_type) == "CostEntry" ? CostEntry : TimeEntry
      scope.find_by!(project: @project, id: params.dig(:write_down, :entry_id))
    end

    def payment_params
      params.expect(payment: %i[received_on amount payment_method reference note])
    end

    def certificate_params
      params.expect(certificate: %i[received_on amount period note])
    end

    def retainer_params
      params.expect(retainer_entry: %i[entry_on kind amount reference note])
    end

    def terms_params
      params.expect(engagement_terms: [:withholds_ewt, :ewt_rate, :payment_terms_days, :retainer_minimum,
                                       { role_rates: {} }])
    end
  end
end
