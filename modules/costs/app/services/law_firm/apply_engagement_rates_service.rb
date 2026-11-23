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
  # Brings the hourly rates of a matter's team in line with the rates agreed
  # for the matter. A changed rate starts today, so time already logged keeps
  # its price; people without a rate on the matter get one the usual way.
  class ApplyEngagementRatesService
    def initialize(project, config: BillingConfig.current)
      @project = project
      @config = config
    end

    def call
      terms = EngagementTerms.for(project)
      return 0 if terms.nil? || !project.module_enabled?(:costs)

      members.count { |member| apply(member, terms) }
    end

    private

    attr_reader :project, :config

    def members
      Member.where(project:, entity_type: nil).includes(:principal, :roles)
            .select { |member| member.principal.is_a?(User) || member.principal.is_a?(PlaceholderUser) }
    end

    def apply(member, terms)
      rate = agreed_rate(member, terms)
      return false if rate.nil?

      current = current_rate(member.principal)
      return ApplyRoleRateService.new(member, config:).call.present? if current.nil?
      return false if current.rate.to_d == rate

      change_rate(current, member.principal, rate)
      true
    end

    def agreed_rate(member, terms)
      role_names = member.roles.map(&:name)
      terms.hourly_rate_for(role_names) || config.hourly_rate_for(role_names)
    end

    def change_rate(current, principal, rate)
      if current.valid_from == Date.current
        current.update!(rate:)
      else
        HourlyRate.create!(principal:, project:, rate:, valid_from: Date.current)
      end
    end

    def current_rate(principal)
      HourlyRate.for_principal(principal).in_project(project).in_effect_at(Date.current).newest_first.first ||
        HourlyRate.for_principal(principal).in_project(project).newest_first.first
    end
  end
end
