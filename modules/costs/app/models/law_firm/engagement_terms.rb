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
  # The billing terms agreed with the client for one matter: hourly rates per
  # role, whether the client withholds EWT, payment terms and the retainer
  # balance to keep.
  class EngagementTerms < ApplicationRecord
    self.table_name = "law_firm_engagement_terms"

    belongs_to :project

    validates :ewt_rate, numericality: { greater_than: 0, less_than: 1 }, allow_nil: true
    validates :payment_terms_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :retainer_minimum, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :role_rates_are_amounts

    def self.for(project)
      find_by(project:)
    end

    def role_rate(role_name)
      value = role_rates.find { |name, _| name.casecmp?(role_name.to_s) }&.last
      BigDecimal(value.to_s) if value.present?
    end

    def hourly_rate_for(role_names)
      role_names.filter_map { |name| role_rate(name) }.max
    end

    def role_rates=(rates)
      super(rates.to_h.transform_keys(&:to_s).compact_blank.transform_values(&:to_s))
    end

    private

    def role_rates_are_amounts
      return if role_rates.values.all? { |value| value.to_s.match?(/\A\d+(\.\d+)?\z/) }

      errors.add(:role_rates, :invalid)
    end
  end
end
