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
  # Removes OpenProject's demo and developer sample projects, and locks the
  # sample users they come with (their passwords equal their logins).
  # Administrators are never locked, so nobody is shut out of the firm.
  # Firm data is never touched: only the stock seed identifiers are matched.
  class SampleDataCleanup
    PROJECT_IDENTIFIERS = %w[
      demo-project
      your-scrum-project
      dev-empty
      dev-work-package-sharing
      dev-large
      dev-large-child
      dev-custom-fields
      dev-forums
    ].freeze
    SAMPLE_USER_MAIL_DOMAIN = "@example.net"

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def call
      removed = sample_projects.filter_map { |project| delete(project) }
      locked = lock_sample_users

      ServiceResult.success(result: { removed_projects: removed, locked_users: locked })
    end

    private

    def sample_projects
      projects = Project.where(identifier: PROJECT_IDENTIFIERS).to_a
      projects.reject { |project| projects.include?(project.parent) }
    end

    def delete(project)
      name = project.name
      result = ::Projects::DeleteService.new(user:, model: project).call
      raise ArgumentError, "Could not remove #{name}: #{result.errors.full_messages.join(', ')}" if result.failure?

      name
    end

    def lock_sample_users
      ::User
        .not_locked
        .where("LOWER(mail) LIKE ?", "%#{SAMPLE_USER_MAIL_DOMAIN}")
        .where(admin: false)
        .find_each
        .map do |sample_user|
          sample_user.update_column(:status, ::User.statuses[:locked])
          sample_user.login
        end
    end
  end
end
