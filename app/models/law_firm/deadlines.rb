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
  module Deadlines
    TYPE_NAMES = ["Court deadline", "Hearing"].freeze
    LOOKAHEAD_DAYS = 30

    module_function

    def types(project = nil)
      scope = ::Type.where(name: TYPE_NAMES)
      scope = scope.enabled_in(project.id) if project.present?
      scope
    end

    def type_ids(project = nil)
      types(project).pluck(:id).map(&:to_s)
    end

    def due_soon_or_overdue(user:, project: nil, until_date: Time.zone.today + LOOKAHEAD_DAYS)
      scope = ::WorkPackage
        .visible(user)
        .with_status_open
        .where(type: types(project))
        .where(due_date: ..until_date)
      scope = scope.where(project:) if project.present?
      scope
        .includes(:project, :type, :status)
        .order(:due_date, :id)
    end
  end
end
