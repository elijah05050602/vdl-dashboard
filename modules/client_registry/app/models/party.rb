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

class Party < ApplicationRecord
  KINDS = %w[person organization government].freeze
  TIN_LENGTHS = [9, 12, 14].freeze

  belongs_to :author, class_name: "User", optional: true
  has_many :aliases, -> { order(:id) },
           class_name: "PartyAlias", inverse_of: :party, dependent: :delete_all
  has_many :matter_parties, dependent: :restrict_with_error
  has_many :projects, through: :matter_parties

  accepts_nested_attributes_for :aliases,
                                allow_destroy: true,
                                reject_if: ->(attributes) { attributes["name"].blank? && attributes["id"].blank? }

  normalizes :name, with: ->(value) { value.squish }
  normalizes :email, with: ->(value) { value.strip.downcase.presence }
  normalizes :phone, :address, :notes, with: ->(value) { value.strip.presence }
  normalizes :tin, with: ->(value) { value.gsub(/\D/, "").presence }

  validates :name, presence: true, length: { maximum: 255 }
  validates :kind, inclusion: { in: KINDS }
  validates :tin, uniqueness: true, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validate :tin_has_valid_length

  scope :ordered, -> { order(Arel.sql("LOWER(parties.name)")) }

  def self.search(text)
    term = text.to_s.squish
    return all if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    digits = term.gsub(/\D/, "")
    alias_match = PartyAlias.where("party_aliases.name ILIKE ?", pattern).select(:party_id)

    scope = where("parties.name ILIKE :pattern OR parties.email ILIKE :pattern", pattern:)
      .or(where(id: alias_match))
    scope = scope.or(where("parties.tin LIKE ?", "#{digits}%")) if digits.length >= 3
    scope
  end

  def person?
    kind == "person"
  end

  def organization?
    kind == "organization"
  end

  def formatted_tin
    return if tin.blank?

    [tin[0, 3], tin[3, 3], tin[6, 3], tin[9..]].compact_blank.join("-")
  end

  def all_names
    [name, *aliases.map(&:name)]
  end

  private

  def tin_has_valid_length
    return if tin.nil? || TIN_LENGTHS.include?(tin.length)

    errors.add(:tin, :invalid_tin)
  end
end
