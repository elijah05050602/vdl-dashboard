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

module DataPrivacy
  class Consent < ApplicationRecord
    self.table_name = "data_privacy_consents"

    SUBJECT_ROLES = %w[client client_representative witness opposing_party employee other].freeze

    belongs_to :project
    belongs_to :author, class_name: "User"

    acts_as_attachable view_permission: :view_data_privacy_consents,
                       add_permission: :manage_data_privacy_consents,
                       delete_permission: :manage_data_privacy_consents,
                       allow_uncontainered: false

    validates :data_subject, :consent_given_on, :scope, presence: true
    validates :data_subject, length: { maximum: 255 }
    validates :subject_role, inclusion: { in: SUBJECT_ROLES }
    validate :withdrawal_after_consent

    scope :active, -> { where(withdrawn_on: nil) }
    scope :withdrawn, -> { where.not(withdrawn_on: nil) }
    scope :by_subject, -> { order(:data_subject, consent_given_on: :desc) }

    def withdrawn?
      withdrawn_on.present?
    end

    private

    def withdrawal_after_consent
      return if withdrawn_on.nil? || consent_given_on.nil? || withdrawn_on >= consent_given_on

      errors.add(:withdrawn_on, :greater_than_or_equal_to, count: I18n.l(consent_given_on))
    end
  end
end
