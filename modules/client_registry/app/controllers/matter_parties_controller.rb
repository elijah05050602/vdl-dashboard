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

class MatterPartiesController < ApplicationController
  helper ClientRegistryHelper

  before_action :find_project_by_project_id
  before_action :authorize
  before_action :find_matter_party, only: %i[update destroy]

  menu_item :matter_parties

  def index
    @matter_parties = @project.matter_parties.includes(party: :aliases).ordered
    @new_matter_party = @project.matter_parties.build(role: "client")
    load_party_options
  end

  def create
    @new_matter_party = @project.matter_parties.build(matter_party_params)

    if @new_matter_party.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_matter_parties_path(@project)
    else
      @matter_parties = @project.matter_parties.where.not(id: nil).includes(party: :aliases).ordered
      load_party_options
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @matter_party.update(matter_party_params.slice(:role, :notes))
      flash[:notice] = I18n.t(:notice_successful_update)
    else
      flash[:error] = @matter_party.errors.full_messages.to_sentence
    end
    redirect_to project_matter_parties_path(@project)
  end

  def destroy
    @matter_party.destroy!
    flash[:notice] = I18n.t(:notice_successful_delete)
    redirect_to project_matter_parties_path(@project)
  end

  private

  def find_matter_party
    @matter_party = @project.matter_parties.find(params.expect(:id))
  end

  def load_party_options
    @party_options = Party.ordered.pluck(:name, :id)
  end

  def matter_party_params
    params.expect(matter_party: %i[party_id role notes])
  end
end
