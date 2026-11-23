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

class PartiesController < ApplicationController
  include PaginationHelper

  helper ClientRegistryHelper

  NEW_ALIAS_ROWS = 3

  before_action :authorize_global
  before_action :find_party, only: %i[show edit update destroy]

  layout "global"

  menu_item :client_registry

  def index
    @query = params[:q].to_s.squish
    @parties = Party
      .search(@query)
      .ordered
      .includes(:aliases)
      .paginate(page: page_param, per_page: per_page_param)
    @matter_counts = MatterParty.where(party_id: @parties.map(&:id)).group(:party_id).count
  end

  def show
    @visible_links, hidden_links = matter_links_by_visibility
    @hidden_matter_count = hidden_links.map(&:project_id).uniq.size
  end

  def new
    @party = Party.new(kind: "person")
    build_alias_rows
  end

  def edit
    build_alias_rows
  end

  def create
    @party = Party.new(party_params.merge(author: current_user))

    if @party.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to party_path(@party)
    else
      build_alias_rows
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @party.update(party_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to party_path(@party)
    else
      build_alias_rows
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @party.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
      redirect_to parties_path
    else
      flash[:error] = I18n.t("client_registry.party.cannot_delete_linked")
      redirect_to party_path(@party)
    end
  end

  private

  def find_party
    @party = Party.find(params.expect(:id))
  end

  def matter_links_by_visibility
    links = @party.matter_parties.includes(:project).ordered.to_a
    visible_ids = Project.visible(current_user).where(id: links.map(&:project_id)).pluck(:id).to_set
    links.partition { |link| visible_ids.include?(link.project_id) }
  end

  def build_alias_rows
    missing = NEW_ALIAS_ROWS - @party.aliases.count(&:new_record?)
    missing.times { @party.aliases.build(alias_type: "other_name") }
  end

  def party_params
    params
      .expect(party: [:kind, :name, :tin, :email, :phone, :address, :notes,
                      { aliases_attributes: [%i[id name alias_type _destroy]] }])
  end
end
