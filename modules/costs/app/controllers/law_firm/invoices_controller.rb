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
  class InvoicesController < ApplicationController
    menu_item :law_firm_invoices

    before_action :find_project_by_project_id
    before_action :authorize
    before_action :find_invoice, only: %i[show cancel]

    def index
      @invoices = Invoice.where(project: @project).newest_first.includes(:issued_by, :cancelled_by)
      @can_issue = User.current.allowed_in_project?(:issue_law_firm_invoices, @project)
    end

    def show
      reprint = @invoice.reprint?
      pdf = Invoices::PDF.new(@invoice, reprint:)
      data = pdf.render
      @invoice.record_print!

      send_data data, filename: pdf.filename, type: "application/pdf", disposition: "inline"
    end

    def new
      @invoice_request = new_request(default_request_attributes)
      prepare_form
    end

    def draft
      @invoice_request = new_request(request_params)

      if @invoice_request.valid?
        pdf = Invoices::PDF.new(draft_invoice, draft: true)
        send_data pdf.render, filename: pdf.filename, type: "application/pdf", disposition: "inline"
      else
        prepare_form
        render :new, status: :unprocessable_entity
      end
    end

    def create
      @invoice_request = new_request(request_params)
      call = issue_service.call(@invoice_request)

      if call.success?
        flash[:notice] = t("law_firm_invoices.issued_notice", number: call.result.number)
        redirect_to project_invoices_path(@project)
      else
        prepare_form
        render :new, status: :unprocessable_entity
      end
    end

    def cancel
      cancel_invoice(params[:cancellation_reason].to_s.strip) unless @invoice.cancelled?
      redirect_to project_invoices_path(@project)
    end

    private

    def billing_config
      @billing_config ||= BillingConfig.current
    end

    def cancel_invoice(reason)
      if reason.blank?
        flash[:error] = t("law_firm_invoices.cancel_reason_required")
      else
        @invoice.update!(cancelled_at: Time.current, cancelled_by: User.current, cancellation_reason: reason)
        flash[:notice] = t("law_firm_invoices.cancelled_notice", number: @invoice.number)
      end
    end

    def issue_service
      Invoices::IssueService.new(user: User.current, project: @project, config: billing_config)
    end

    def find_invoice
      @invoice = Invoice.find_by!(project: @project, id: params.expect(:id))
    end

    def new_request(attributes)
      Invoices::Request.new(attributes).tap { |request| request.allowed_ewt_rates = billing_config.invoice.ewt_rates }
    end

    def request_params
      params.fetch(:invoice, {}).permit(:period_from, :period_to, :client_name, :client_address,
                                        :client_tin, :client_withholds, :ewt_rate).to_h
    end

    def default_request_attributes
      last = Invoice.active.where(project: @project).newest_first.first
      today = User.current.today

      {
        period_from: default_period_from(last, today),
        period_to: today,
        client_name: last&.client_name,
        client_address: last&.client_address,
        client_tin: last&.client_tin,
        client_withholds: last&.ewt_rate.present?,
        ewt_rate: last&.ewt_rate || billing_config.ewt_rate
      }
    end

    def default_period_from(last_invoice, today)
      next_day = last_invoice&.period_to&.next_day
      next_day && next_day <= today ? next_day : today.beginning_of_month
    end

    def prepare_form
      @ewt_rates = billing_config.invoice.ewt_rates
      @missing_details = billing_config.invoice.missing_details
      @statement = issue_service.build_statement(@invoice_request) if period_valid?
    end

    def period_valid?
      @invoice_request.period_from.present? && @invoice_request.period_to.present? &&
        @invoice_request.period_from <= @invoice_request.period_to
    end

    def draft_invoice
      statement = issue_service.build_statement(@invoice_request)
      Invoice.new(statement.invoice_attributes.merge(
                    issued_on: User.current.today,
                    client_name: @invoice_request.client_name,
                    client_address: @invoice_request.client_address,
                    client_tin: @invoice_request.client_tin
                  ))
    end
  end
end
