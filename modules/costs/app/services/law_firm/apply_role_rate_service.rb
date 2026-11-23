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
  class ApplyRoleRateService
    def initialize(member, config: BillingConfig.current)
      @member = member
      @config = config
    end

    def call
      return unless applicable?

      role_names = member.roles.map(&:name)
      rate = EngagementTerms.for(project)&.hourly_rate_for(role_names) || config.hourly_rate_for(role_names)
      return if rate.nil?

      HourlyRate.transaction(requires_new: true) do
        HourlyRate.create!(principal:, project:, rate:, valid_from:)
      end
    end

    private

    attr_reader :member, :config

    def applicable?
      project.present? &&
        (principal.is_a?(User) || principal.is_a?(PlaceholderUser)) &&
        project.module_enabled?(:costs) &&
        !HourlyRate.for_principal(principal).in_project(project).exists?
    end

    def principal
      member.principal
    end

    def project
      member.project
    end

    # Time logged before the rate existed is priced with it only when it has no
    # price yet, so amounts already costed with a default rate do not change.
    def valid_from
      return Date.current if DefaultHourlyRate.for_principal(principal).exists?

      [TimeEntry.for_principal(principal).in_project(project).minimum(:spent_on), Date.current].compact.min
    end
  end
end
