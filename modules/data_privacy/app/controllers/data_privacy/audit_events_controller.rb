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

require "csv"

module DataPrivacy
  class AuditEventsController < ::ApplicationController
    CSV_LIMIT = 50_000

    layout "admin"

    before_action :require_admin

    menu_item :audit_trail

    def index
      @filters = filter_params
      events = filtered_events.newest_first

      respond_to do |format|
        format.html do
          @events = events.includes(:user, :project, :resource).paginate(page: helpers.page_param(params),
                                                              per_page: helpers.per_page_param(params))
          @users = User.where(id: AuditEvent.select(:user_id)).order(:lastname, :firstname)
          @projects = Project.where(id: AuditEvent.select(:project_id)).order(:name)
        end
        format.csv do
          send_data to_csv(events.limit(CSV_LIMIT)), type: "text/csv", filename: "audit-trail-#{Time.zone.today.iso8601}.csv"
        end
      end
    end

    private

    def filter_params
      params.permit(:user_id, :project_id, :event, :from, :to).to_h.symbolize_keys.compact_blank
    end

    def filtered_events
      scope = AuditEvent.all
      scope = scope.where(user_id: @filters[:user_id]) if @filters[:user_id]
      scope = scope.where(project_id: @filters[:project_id]) if @filters[:project_id]
      scope = scope.where(action: @filters[:event]) if @filters[:event]
      scope = scope.where(created_at: parse_date(:from).beginning_of_day..) if parse_date(:from)
      scope = scope.where(created_at: ..parse_date(:to).end_of_day) if parse_date(:to)
      scope
    end

    def parse_date(key)
      Date.iso8601(@filters[key]).in_time_zone if @filters[key]
    rescue Date::Error
      nil
    end

    def to_csv(events)
      CSV.generate do |csv|
        csv << csv_headers
        events.includes(:user, :project, :resource).each do |event|
          csv << [event.created_at.iso8601, event.user_label, event.action, event.project_label,
                  event.resource_label, event.description, event.http_method, event.path, event.remote_ip]
                   .map { spreadsheet_safe(it) }
        end
      end
    end

    # Keeps a crafted path or name from running as a formula when the file is opened in a spreadsheet.
    def spreadsheet_safe(value)
      value.to_s.match?(/\A[=+\-@\t\r]/) ? "'#{value}" : value
    end

    def csv_headers
      %w[time user event matter record activity method path ip].map { I18n.t("data_privacy.audit.columns.#{it}") }
    end
  end
end
