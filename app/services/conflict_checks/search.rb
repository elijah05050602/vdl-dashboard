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

module ConflictChecks
  class Search
    Match = Data.define(:project, :source, :value, :role)

    SEARCHABLE_FORMATS = %w[string text].freeze
    MIN_TOKEN_LENGTH = 2
    ENTITY_SUFFIXES = %w[
      inc incorporated corp corporation co company llc llp lp ltd limited plc
      gmbh ag sa bv pc pa pllc the and of
    ].freeze

    ROLE_PATTERNS = {
      opposing: /opposing|adverse|defendant|respondent|other\s*party|counter\s*party/i,
      client: /client|plaintiff|petitioner/i
    }.freeze

    attr_reader :query, :user

    def initialize(query:, user: User.current)
      @query = query.to_s.strip
      @user = user
    end

    def tokens
      @tokens ||= self.class.normalize(query)
    end

    def searchable?
      tokens.any?
    end

    def call
      return [] unless searchable?

      (project_name_matches + custom_value_matches)
        .sort_by { |m| [role_rank(m.role), m.project.name.downcase] }
    end

    def self.normalize(text)
      words = I18n.transliterate(text.to_s).downcase.scan(/[a-z0-9]+/)
      significant = words - ENTITY_SUFFIXES
      (significant.presence || words).select { |w| w.length >= MIN_TOKEN_LENGTH }.uniq
    end

    def self.role_for(field_name)
      ROLE_PATTERNS.find { |_, pattern| pattern.match?(field_name.to_s) }&.first || :other
    end

    private

    def visible_projects
      Project.visible(user)
    end

    def project_name_matches
      visible_projects
        .where(like_all_tokens("projects.name"))
        .map { |project| Match.new(project:, source: nil, value: project.name, role: :matter) }
    end

    def custom_value_matches
      CustomValue
        .joins("INNER JOIN custom_fields ON custom_fields.id = custom_values.custom_field_id")
        .where(customized_type: "Project", customized_id: visible_projects.select(:id))
        .where(custom_fields: { type: "ProjectCustomField", field_format: SEARCHABLE_FORMATS })
        .where(like_all_tokens("custom_values.value"))
        .includes(:custom_field, :customized)
        .filter_map { |custom_value| to_match(custom_value) }
    end

    def to_match(custom_value)
      field = custom_value.custom_field
      project = custom_value.customized
      return unless field_visible?(field, project)

      Match.new(project:, source: field.name, value: custom_value.value, role: self.class.role_for(field.name))
    end

    def field_visible?(field, project)
      user.admin? || (!field.admin_only? && user.allowed_in_project?(:view_project_attributes, project))
    end

    def like_all_tokens(column)
      table = Arel::Table.new(column.split(".").first)
      attribute = table[column.split(".").last]
      tokens
        .map { |token| attribute.matches("%#{ActiveRecord::Base.sanitize_sql_like(token)}%") }
        .reduce(:and)
    end

    def role_rank(role)
      %i[opposing client matter other].index(role)
    end
  end
end
