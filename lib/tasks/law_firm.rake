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

namespace :law_firm do
  desc "Add Philippine holidays as non-working days, e.g. rake law_firm:ph_holidays[2027] (defaults to this and next year)"
  task :ph_holidays, [:year] => :environment do |_task, args|
    years = args[:year].present? ? [args[:year].to_i] : [Date.current.year, Date.current.year + 1]

    years.each do |year|
      created = LawFirm::PhilippineHolidays.new(year).create_non_working_days
      puts "#{year}: added #{created.size} non-working days"
      created.each { |day| puts "  #{day.date} #{day.name}" }
    end
  end
end
