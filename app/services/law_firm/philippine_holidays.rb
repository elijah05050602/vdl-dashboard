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
  # Philippine regular holidays and special non-working days that fall on a fixed
  # date or follow a fixed rule. Chinese New Year, Eid'l Fitr and Eid'l Adha are
  # proclaimed each year and have to be added by hand under
  # Administration > Calendars and dates > Working days and hours.
  class PhilippineHolidays
    def initialize(year)
      @year = year
    end

    def to_h
      fixed_dates
        .merge(holy_week)
        .merge(national_heroes_day => "National Heroes Day")
        .sort
        .to_h
    end

    def create_non_working_days
      to_h.filter_map do |date, name|
        next if NonWorkingDay.exists?(date:)

        NonWorkingDay.create!(date:, name:)
      end
    end

    private

    attr_reader :year

    def fixed_dates
      {
        [1, 1] => "New Year's Day",
        [4, 9] => "Araw ng Kagitingan",
        [5, 1] => "Labor Day",
        [6, 12] => "Independence Day",
        [8, 21] => "Ninoy Aquino Day",
        [11, 1] => "All Saints' Day",
        [11, 2] => "All Souls' Day",
        [11, 30] => "Bonifacio Day",
        [12, 8] => "Feast of the Immaculate Conception",
        [12, 24] => "Christmas Eve",
        [12, 25] => "Christmas Day",
        [12, 30] => "Rizal Day",
        [12, 31] => "Last Day of the Year"
      }.transform_keys { |month, day| Date.new(year, month, day) }
    end

    def holy_week
      easter = easter_sunday
      {
        easter - 3.days => "Maundy Thursday",
        easter - 2.days => "Good Friday",
        easter - 1.day => "Black Saturday"
      }
    end

    def national_heroes_day
      last_day = Date.new(year, 8, -1)
      last_day - ((last_day.wday - 1) % 7).days
    end

    # Anonymous Gregorian algorithm
    def easter_sunday # rubocop:disable Metrics/AbcSize
      a = year % 19
      b, c = year.divmod(100)
      d, e = b.divmod(4)
      f = (b + 8) / 25
      g = (b - f + 1) / 3
      h = ((19 * a) + b - d - g + 15) % 30
      i, k = c.divmod(4)
      l = (32 + (2 * e) + (2 * i) - h - k) % 7
      m = (a + (11 * h) + (22 * l)) / 451
      month, day = (h + l - (7 * m) + 114).divmod(31)
      Date.new(year, month, day + 1)
    end
  end
end
