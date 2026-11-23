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
    Match = Data.define(:project, :source, :value, :role, :restricted) do
      delegate :archived?, to: :project
    end

    SEARCHABLE_FORMATS = %w[string text].freeze
    MIN_TOKEN_LENGTH = 2

    ABBREVIATIONS = {
      /\bma\./i => "maria ", /\bsta\./i => "santa ", /\bsto\./i => "santo ", /\bphils?\./i => "philippines "
    }.freeze

    IGNORED_WORDS = %w[
      inc incorporated corp corporation company cos llc llp lp ltd limited plc opc
      gmbh ag sa bv pc pa pllc the and of
      jr sr ii iii iv
      atty dr engr hon mr mrs ms sps spouses
    ].freeze

    PARTICLES = %w[de del dela delas delos la las los san santa santo].freeze

    NAME_SEPARATORS = /[;\n|]|\s+(?:and|vs?\.?|versus)\s+|\s+&\s+|\//i

    ROLE_PATTERNS = {
      opposing: /opposing|adverse|other\s*party|counter\s*party/i,
      client: /client/i
    }.freeze

    attr_reader :query, :user

    def initialize(query:, user: User.current)
      @query = query.to_s.strip
      @user = user
    end

    def tokens
      @tokens ||= self.class.normalize(query)
    end

    def expanded_tokens
      @expanded_tokens ||= self.class.normalize(query, expand: true)
    end

    def searchable?
      tokens.any?
    end

    def call
      return [] unless searchable?

      (project_name_matches + custom_value_matches)
        .sort_by { |m| [role_rank(m.role), m.project.name.downcase] }
    end

    def self.normalize(text, expand: false)
      expanded = ABBREVIATIONS.reduce(I18n.transliterate(text.to_s)) { |str, (pattern, word)| str.gsub(pattern, word) }
      words = expanded.downcase.scan(/[a-z0-9]+/)
      significant = words - IGNORED_WORDS
      significant = words if significant.empty?
      join_particles(significant, expand:).select { |w| w.length >= MIN_TOKEN_LENGTH }.uniq
    end

    def self.join_particles(words, expand: false)
      prefix = +""
      joined = words.each_with_object([]) do |word, result|
        if PARTICLES.include?(word)
          prefix << word
        else
          result << (prefix + word)
          result << word if expand && prefix.present?
          prefix = +""
        end
      end
      prefix.empty? ? joined : joined << prefix
    end

    def self.names_match?(query_tokens, text, expanded_query = query_tokens)
      split_names(text).any? do |name|
        name_tokens = normalize(name)
        next false if name_tokens.empty?

        (query_tokens - normalize(name, expand: true)).empty? ||
          (name_tokens.size >= 2 && (name_tokens - expanded_query).empty?)
      end
    end

    # "Spouses Juan and Maria Santos" names two people who share the last surname.
    def self.split_names(text)
      parts = text.to_s.split(NAME_SEPARATORS).map(&:strip).reject(&:empty?)
      parts.each_with_index.map do |part, index|
        following = parts[index + 1]
        if following && normalize(part).size == 1
          "#{part} #{following.split.last}"
        else
          part
        end
      end
    end

    def self.role_for(field_name)
      ROLE_PATTERNS.find { |_, pattern| pattern.match?(field_name.to_s) }&.first || :other
    end

    private

    def project_name_matches
      Project
        .select { |project| names_match?(project.name) }
        .map { |project| build_match(project, nil, project.name, :matter) }
    end

    def custom_value_matches
      candidate_custom_values
        .select { |custom_value| custom_value.customized && names_match?(custom_value.value) }
        .map do |custom_value|
          field = custom_value.custom_field
          build_match(custom_value.customized, field, custom_value.value, self.class.role_for(field.name))
        end
    end

    def candidate_custom_values
      CustomValue
        .joins("INNER JOIN custom_fields ON custom_fields.id = custom_values.custom_field_id")
        .where(customized_type: "Project")
        .where(custom_fields: { type: "ProjectCustomField", field_format: SEARCHABLE_FORMATS })
        .where.not(value: [nil, ""])
        .includes(:custom_field, :customized)
    end

    def names_match?(text)
      self.class.names_match?(tokens, text, expanded_tokens)
    end

    def build_match(project, field, value, role)
      if details_visible?(project, field)
        Match.new(project:, source: field&.name, value:, role:, restricted: false)
      else
        Match.new(project:, source: nil, value: nil, role:, restricted: true)
      end
    end

    def details_visible?(project, field)
      return true if user.active_admin?
      return false unless known_project_ids.include?(project.id)
      return true if field.nil?
      return false if field.admin_only? || project.project_custom_field_ids.exclude?(field.id)

      project.archived? || user.allowed_in_project?(:view_project_attributes, project)
    end

    def known_project_ids
      @known_project_ids ||= Project
        .where(public: true)
        .or(Project.where(id: user.members.select(:project_id)))
        .pluck(:id)
        .to_set
    end

    def role_rank(role)
      %i[opposing client matter other].index(role)
    end
  end
end
