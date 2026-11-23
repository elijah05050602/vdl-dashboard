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

module DemoData
  module LawFirm
    class PhilippineHolidaysSeeder < ::Seeder
      SEED_FILE = Rails.root.join("app/seeders/law_firm/philippine_holidays.yml")

      def seed_data!
        pending_holidays.each do |holiday|
          NonWorkingDay.create!(date: holiday["date"], name: holiday["name"])
        end
        WorkPackages::Shared::WorkingDays.clear_cache
      end

      def applicable?
        !Rails.env.test? && pending_holidays.any? && super
      end

      def holidays
        @holidays ||= YAML.load_file(SEED_FILE, permitted_classes: [Date]).fetch("holidays")
      end

      private

      def pending_holidays
        existing = NonWorkingDay.where(date: holidays.pluck("date")).pluck(:date)
        holidays.reject { |holiday| existing.include?(holiday["date"]) }
      end
    end
  end
end
