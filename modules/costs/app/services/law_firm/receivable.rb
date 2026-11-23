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
  # What is owed on one issued invoice: payments received, balance, due date
  # and whether the client's BIR Form 2307 for the withheld tax has come in.
  class Receivable
    BUCKETS = %w[current days_1_30 days_31_60 days_61_90 over_90].freeze

    attr_reader :invoice, :paid, :certified

    def self.for_projects(projects, config: BillingConfig.current)
      invoices = Invoice.active.where(project: projects).includes(:project).order(:issued_on, :serial).to_a
      paid = sums_by_invoice(Payment, invoices)
      certified = sums_by_invoice(WithholdingCertificate, invoices)
      terms_days = payment_terms_by_project(invoices, config)

      invoices.map do |invoice|
        new(invoice, paid: paid.fetch(invoice.id, 0), certified: certified.fetch(invoice.id, 0),
                     terms_days: terms_days[invoice.project_id])
      end
    end

    def self.sums_by_invoice(model, invoices)
      model.where(invoice_id: invoices.map(&:id)).group(:invoice_id).sum(:amount)
    end

    def self.payment_terms_by_project(invoices, config)
      terms = EngagementTerms.where(project_id: invoices.map(&:project_id)).pluck(:project_id, :payment_terms_days).to_h
      Hash.new(config.payment_terms_days).merge(terms.compact)
    end

    def initialize(invoice, paid:, certified:, terms_days:)
      @invoice = invoice
      @paid = paid.to_d
      @certified = certified.to_d
      @terms_days = terms_days.to_i
    end

    delegate :project, :number, :issued_on, :client_name, :amount_due, :ewt_amount, to: :invoice

    def due_on
      issued_on + @terms_days
    end

    def balance
      [amount_due - paid, 0.to_d].max
    end

    def paid?
      balance.zero?
    end

    def open?
      !paid?
    end

    def certificate_missing?
      ewt_amount.to_d.positive? && certified < ewt_amount
    end

    def days_overdue(today = Date.current)
      (today - due_on).to_i
    end

    def bucket(today = Date.current)
      days = days_overdue(today)
      if days <= 0 then "current"
      elsif days <= 30 then "days_1_30"
      elsif days <= 60 then "days_31_60"
      elsif days <= 90 then "days_61_90"
      else "over_90"
      end
    end
  end
end
