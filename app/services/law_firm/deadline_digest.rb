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
  class DeadlineDigest
    Entry = Data.define(:work_package, :days_left) do
      def overdue? = days_left.negative?
    end

    attr_reader :user, :today

    def self.deadline_types
      Type.where(name: Array(Setting.deadline_reminder_types).map(&:to_s))
    end

    def self.reminder_days
      Array(Setting.deadline_reminder_days).map(&:to_i).uniq.sort.reverse
    end

    def initialize(user, today: Date.current)
      @user = user
      @today = today
    end

    def empty?
      reminders.empty? && upcoming.empty?
    end

    def reminders
      @reminders ||= entries_for(
        deadlines
          .where(id: WorkPackage.involving_user(user).select(:id))
          .where("work_packages.due_date < :today OR work_packages.due_date IN (:dates)",
                 today:, dates: reminder_dates)
      )
    end

    def upcoming
      @upcoming ||= entries_for(
        in_my_matters(deadlines).where(due_date: today..(today + Setting.deadline_digest_days_ahead.to_i.days))
      )
    end

    def overdue
      @overdue ||= entries_for(in_my_matters(deadlines).where(due_date: ...today))
    end

    private

    def deadlines
      WorkPackage
        .visible(user)
        .with_status_open
        .where(type: self.class.deadline_types)
        .where.not(due_date: nil)
        .includes(:project, :type, :status, :assigned_to)
        .order(:due_date, :id)
    end

    def in_my_matters(scope)
      scope.where(project_id: Member.where(principal: [user, *user.groups], entity_type: nil).select(:project_id))
    end

    def reminder_dates
      self.class.reminder_days.map { |days| today + days.days }
    end

    def entries_for(scope)
      scope.map { |work_package| Entry.new(work_package:, days_left: (work_package.due_date - today).to_i) }
    end
  end
end
