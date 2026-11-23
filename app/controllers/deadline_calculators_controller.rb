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


class DeadlineCalculatorsController < ApplicationController
  menu_item :deadline_calculator

  before_action :find_project_by_project_id, :authorize
  before_action :load_form

  def show; end

  def create
    return render(:show, status: :unprocessable_entity) unless @calculation && @court_deadline_type

    result = DeadlineCalculator::CreateCourtDeadlineService
               .new(user: current_user, project: @project)
               .call(calculation: @calculation, assigned_to: selected_assignee)

    if result.success?
      flash[:notice] = t("deadline_calculator.created", date: helpers.format_date(@calculation.due_on))
      redirect_to project_work_package_path(@project, result.result)
    else
      @errors = result.errors.full_messages
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_form
    @court_deadline_type = DeadlineCalculator::CreateCourtDeadlineService.court_deadline_type(@project)
    @grouped_periods = DeadlineCalculator::Period.grouped
    @received_on = parse_date(params[:received_on])
    @period = selected_period
    @assignees = Principal.possible_assignee(@project).ordered_by_name
    @calculation = DeadlineCalculator::Calculation.new(received_on: @received_on, period: @period) if @received_on && @period&.valid?
  end

  def selected_period
    if params[:period] == DeadlineCalculator::Period::CUSTOM_KEY
      DeadlineCalculator::Period.custom(name: params[:custom_name], days: params[:custom_days], rule: params[:custom_rule])
    else
      DeadlineCalculator::Period.find(params[:period])
    end
  end

  def selected_assignee
    @assignees.find_by(id: params[:assigned_to_id]) if params[:assigned_to_id].present?
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
