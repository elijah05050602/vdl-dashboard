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
  class CourtCalendar
    VIEWS = %w[month week day].freeze
    DEFAULT_VIEW = "month"

    Entry = Data.define(:work_package, :date, :time, :time_position, :kind, :court, :court_id,
                        :branch, :courtroom, :judge, :appearance, :lawyer) do
      def closed? = work_package.closed?
    end

    attr_reader :user, :view, :date, :lawyer_id, :court_id

    def initialize(user:, view: nil, date: nil, lawyer_id: nil, court_id: nil)
      @user = user
      @view = VIEWS.include?(view.to_s) ? view.to_s : DEFAULT_VIEW
      @date = parse_date(date) || user.today
      @lawyer_id = lawyer_id.presence&.to_i
      @court_id = court_id.presence&.to_i
    end

    def configured?
      type_ids.any?
    end

    def days
      @days ||=
        case view
        when "month"
          beginning_of_week(date.beginning_of_month)..(beginning_of_week(date.end_of_month) + 6)
        when "week"
          beginning_of_week(date)..(beginning_of_week(date) + 6)
        else
          date..date
        end
    end

    def weeks
      days.each_slice(7).to_a
    end

    def in_period?(day)
      view == "month" ? day.month == date.month : days.cover?(day)
    end

    def previous_date
      shift(-1)
    end

    def next_date
      shift(1)
    end

    def entries
      @entries ||= load_entries
    end

    def entries_on(day)
      entries_by_day.fetch(day, [])
    end

    def holiday_name(day)
      holidays[day]
    end

    def working_day?(day)
      Setting.working_days.include?(day.cwday) && !holidays.key?(day)
    end

    def lawyer_options
      return Principal.none unless configured?

      ids = hearing_scope.where.not(assigned_to_id: nil).distinct.pluck(:assigned_to_id)
      if (lawyer_field = fields[:lawyer])
        ids += CustomValue
          .where(custom_field: lawyer_field, customized_type: "WorkPackage", customized_id: hearing_scope.select(:id))
          .where.not(value: [nil, ""])
          .distinct
          .pluck(:value)
          .map(&:to_i)
      end

      Principal.visible(user).where(id: ids.uniq | [user.id]).ordered_by_name
    end

    def court_options
      court_field = fields[:court]
      court_field ? court_field.custom_options.order(:position) : CustomOption.none
    end

    def fields
      @fields ||= Hearings.fields
    end

    private

    def load_entries
      return [] unless configured?

      work_packages = hearing_scope
        .where("COALESCE(work_packages.due_date, work_packages.start_date) BETWEEN :from AND :to",
               from: days.first, to: days.last)
        .includes(:project, :status, :assigned_to, :type)
        .to_a
      values = custom_values_for(work_packages.map(&:id))
      lawyers = lawyers_in(values)

      work_packages
        .map { |work_package| build_entry(work_package, values.fetch(work_package.id, {}), lawyers) }
        .select { |entry| matches_filters?(entry) }
        .sort_by { |entry| [entry.date, entry.time_position || Float::INFINITY, entry.work_package.subject.to_s] }
    end

    def entries_by_day
      @entries_by_day ||= entries.group_by(&:date)
    end

    def hearing_scope
      WorkPackage.visible(user).where(type_id: type_ids)
    end

    def type_ids
      @type_ids ||= Hearings.types.pluck(:id)
    end

    def custom_values_for(work_package_ids)
      field_ids = fields.values.compact.map(&:id)
      return {} if work_package_ids.empty? || field_ids.empty?

      CustomValue
        .where(customized_type: "WorkPackage", customized_id: work_package_ids, custom_field_id: field_ids)
        .where.not(value: [nil, ""])
        .pluck(:customized_id, :custom_field_id, :value)
        .each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |(work_package_id, field_id, value), values|
          values[work_package_id][field_id] = value
        end
    end

    def build_entry(work_package, values, lawyers)
      time = option_for(:time, values)
      court = option_for(:court, values)
      lawyer_value = value_for(:lawyer, values)

      Entry.new(
        work_package:,
        date: work_package.due_date || work_package.start_date,
        time: time&.value,
        time_position: time&.position,
        kind: option_for(:kind, values)&.value,
        court: court&.value,
        court_id: court&.id,
        branch: value_for(:branch, values),
        courtroom: value_for(:courtroom, values),
        judge: value_for(:judge, values),
        appearance: option_for(:appearance, values)&.value,
        lawyer: (lawyers[lawyer_value.to_i] if lawyer_value) || work_package.assigned_to
      )
    end

    def matches_filters?(entry)
      return false if court_id && entry.court_id != court_id
      return false if lawyer_id && [entry.lawyer&.id, entry.work_package.assigned_to_id].exclude?(lawyer_id)

      true
    end

    def value_for(key, values)
      field = fields[key]
      values[field.id] if field
    end

    def option_for(key, values)
      value = value_for(key, values)
      options[value.to_i] if value
    end

    def options
      @options ||= CustomOption
        .where(custom_field_id: fields.values_at(:time, :kind, :court, :appearance).compact.map(&:id))
        .index_by(&:id)
    end

    def lawyers_in(values)
      field = fields[:lawyer]
      return {} unless field

      ids = values.values.filter_map { |field_values| field_values[field.id]&.to_i }
      Principal.where(id: ids.uniq).index_by(&:id)
    end

    def holidays
      @holidays ||= NonWorkingDay.for_dates(days).to_h { |day| [day.date, day.name] }
    end

    def shift(direction)
      case view
      when "month" then date.beginning_of_month.advance(months: direction)
      when "week" then date + (7 * direction)
      else date + direction
      end
    end

    def beginning_of_week(day)
      day.beginning_of_week(OpenProject::Internationalization::Date.beginning_of_week)
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end
  end
end
