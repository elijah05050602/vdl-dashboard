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
  class Calculation
    SkippedDay = Data.define(:date, :reason)

    attr_reader :received_on, :period

    def initialize(received_on:, period:, working_days: WorkPackages::Shared::WorkingDays.new)
      @received_on = received_on
      @period = period
      @working_days = working_days
    end

    def last_day
      received_on + period.days
    end

    def due_on
      @due_on ||= @working_days.soonest_working_day(last_day)
    end

    def moved?
      due_on != last_day
    end

    def skipped_days
      @skipped_days ||= begin
        holidays = NonWorkingDay.for_dates(last_day...due_on).pluck(:date, :name).to_h
        (last_day...due_on).map do |date|
          SkippedDay.new(date:, reason: holidays[date] || I18n.l(date, format: "%A"))
        end
      end
    end
  end
end
