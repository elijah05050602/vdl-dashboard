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


module DeadlineCalculator
  class CreateCourtDeadlineService
    TYPE_NAME = "Court deadline"

    def self.court_deadline_type(project)
      project.types.find_by(name: TYPE_NAME)
    end

    def initialize(user:, project:)
      @user = user
      @project = project
    end

    def call(calculation:, assigned_to: nil)
      WorkPackages::CreateService
        .new(user: @user)
        .call(project: @project,
              type: self.class.court_deadline_type(@project),
              subject: calculation.period.name.truncate(255),
              start_date: calculation.due_on,
              due_date: calculation.due_on,
              assigned_to:,
              description: description(calculation))
    end

    private

    def description(calculation)
      period = calculation.period
      lines = [
        "**#{I18n.t('deadline_calculator.description.heading')}**",
        "",
        "- #{I18n.t('deadline_calculator.description.received_on', date: format_date(calculation.received_on))}",
        "- #{I18n.t('deadline_calculator.description.period', count: period.days, label: period.label)}",
        "- #{I18n.t('deadline_calculator.description.last_day', date: format_date(calculation.last_day))}"
      ]
      if calculation.moved?
        lines << "- #{I18n.t('deadline_calculator.description.moved',
                             date: format_date(calculation.due_on), reasons: skipped_reasons(calculation))}"
      end
      lines << "" << I18n.t("deadline_calculator.description.counting")
      lines << "" << period.note if period.note.present?
      lines.join("\n")
    end

    def skipped_reasons(calculation)
      calculation.skipped_days
                 .map { |day| "#{format_date(day.date)} (#{day.reason})" }
                 .to_sentence
    end

    def format_date(date)
      I18n.l(date, format: :long)
    end
  end
end
