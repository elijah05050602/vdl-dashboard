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
  module Receivables
    # Records money received on an invoice. A payment made from the matter's
    # retainer also draws that amount from the retainer.
    class RecordPaymentService
      def initialize(user:, invoice:)
        @user = user
        @invoice = invoice
      end

      def call(attributes)
        payment = Payment.new(attributes.merge(invoice:, recorded_by: user))
        return failure(payment) unless payment.valid? && within_balance?(payment) && retainer_covers?(payment)

        Payment.transaction do
          payment.save!
          draw_from_retainer(payment) if payment.payment_method == "retainer"
        end

        ServiceResult.success(result: payment)
      end

      private

      attr_reader :user, :invoice

      def within_balance?(payment)
        return true if payment.amount <= balance

        payment.errors.add(:amount, :less_than_or_equal_to, count: balance.to_s("F"))
        false
      end

      def retainer_covers?(payment)
        return true unless payment.payment_method == "retainer"
        return true if payment.amount <= RetainerEntry.balance(invoice.project)

        payment.errors.add(:amount, :exceeds_retainer)
        false
      end

      def balance
        @balance ||= invoice.amount_due.to_d - Payment.where(invoice:).sum(:amount).to_d
      end

      def draw_from_retainer(payment)
        RetainerEntry.create!(project: invoice.project, payment:, kind: "drawdown", amount: payment.amount,
                              entry_on: payment.received_on, reference: invoice.number, recorded_by: user)
      end

      def failure(payment)
        ServiceResult.failure(result: payment, errors: payment.errors)
      end
    end
  end
end
