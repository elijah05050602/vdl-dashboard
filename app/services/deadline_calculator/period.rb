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
  class Period
    CUSTOM_KEY = "custom"
    MAX_DAYS = 3650
    SOURCE = Rails.root.join("config/law_firm/reglementary_periods.yml")

    attr_reader :key, :group, :name, :days, :rule, :note

    class << self
      def all
        @all ||= source.fetch("periods").map do |entry|
          new(key: entry.fetch("key"),
              group: entry.fetch("group"),
              name: entry.fetch("name"),
              days: Integer(entry.fetch("days")),
              rule: entry.fetch("rule"),
              note: entry["note"])
        end.freeze
      end

      def groups
        @groups ||= source.fetch("groups").freeze
      end

      def find(key)
        all.find { |period| period.key == key.to_s }
      end

      def custom(name:, days:, rule:)
        new(key: CUSTOM_KEY, group: nil, name: name.to_s.strip, days: Integer(days.to_s, 10, exception: false),
            rule: rule.to_s.strip, note: nil)
      end

      def grouped
        all.group_by(&:group).transform_keys { |group| groups.fetch(group, group) }
      end

      private

      def source
        @source ||= YAML.safe_load_file(SOURCE)
      end
    end

    def initialize(key:, group:, name:, days:, rule:, note:) # rubocop:disable Metrics/ParameterLists
      @key = key
      @group = group
      @name = name
      @days = days
      @rule = rule
      @note = note
    end

    def custom?
      key == CUSTOM_KEY
    end

    def valid?
      name.present? && days.is_a?(Integer) && days.between?(1, MAX_DAYS)
    end

    def label
      rule.present? ? "#{name} (#{rule})" : name
    end
  end
end
