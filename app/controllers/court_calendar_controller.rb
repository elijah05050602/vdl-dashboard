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

class CourtCalendarController < ApplicationController
  before_action :require_login
  no_authorization_required! :show

  layout "global"

  menu_item :court_calendar

  helper_method :court_calendar_link

  def show
    @calendar = LawFirm::CourtCalendar.new(
      user: current_user,
      view: params[:view],
      date: params[:date],
      lawyer_id: params[:lawyer],
      court_id: params[:court]
    )
  end

  private

  def court_calendar_link(**overrides)
    filters = {
      view: @calendar.view,
      date: @calendar.date.iso8601,
      lawyer: @calendar.lawyer_id,
      court: @calendar.court_id
    }
    court_calendar_path(filters.merge(overrides).compact_blank)
  end
end
