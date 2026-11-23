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

class MatterParty < ApplicationRecord
  ROLES = %w[client adverse_party opposing_counsel witness related_party].freeze

  belongs_to :project
  belongs_to :party

  normalizes :notes, with: ->(value) { value.strip.presence }

  validates :role, inclusion: { in: ROLES }
  validates :party_id, uniqueness: { scope: %i[project_id role] }

  scope :ordered, -> {
    joins(:party).order(Arel.sql(role_order_sql), Arel.sql("LOWER(parties.name)"))
  }

  def self.role_order_sql
    whens = ROLES.each_with_index.map { |role, index| "WHEN '#{role}' THEN #{index}" }.join(" ")
    "CASE matter_parties.role #{whens} END"
  end
end
