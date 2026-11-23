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
    class Request
      include ActiveModel::Model
      include ActiveModel::Attributes

      TIN_FORMAT = /\A\d{3}-?\d{3}-?\d{3}(-?\d{3,5})?\z/

      attribute :period_from, :date
      attribute :period_to, :date
      attribute :client_name, :string
      attribute :client_address, :string
      attribute :client_tin, :string
      attribute :client_withholds, :boolean, default: false
      attribute :ewt_rate, :decimal

      attr_accessor :allowed_ewt_rates

      validates :period_from, :period_to, :client_name, :client_address, presence: true
      validates :client_tin, format: { with: TIN_FORMAT }, allow_blank: true
      validate :period_in_order
      validate :ewt_rate_allowed

      def self.model_name
        ActiveModel::Name.new(self, nil, "invoice")
      end

      def self.human_attribute_name(attribute, options = {})
        I18n.t("law_firm_invoices.attributes.#{attribute}", default: super)
      end

      def effective_ewt_rate
        client_withholds ? ewt_rate : nil
      end

      private

      def period_in_order
        return if period_from.blank? || period_to.blank? || period_from <= period_to

        errors.add(:period_to, :greater_than_or_equal_to, count: period_from)
      end

      def ewt_rate_allowed
        return unless client_withholds
        return if ewt_rate.present? && Array(allowed_ewt_rates).include?(ewt_rate)

        errors.add(:ewt_rate, :inclusion)
      end
    end
  end
end
