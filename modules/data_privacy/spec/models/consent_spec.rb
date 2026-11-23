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

require "spec_helper"

RSpec.describe DataPrivacy::Consent do
  subject(:consent) { build(:data_privacy_consent) }

  it "is valid with the required details" do
    expect(consent).to be_valid
  end

  it "requires the data subject, the consent date and the scope" do
    consent.assign_attributes(data_subject: "", consent_given_on: nil, scope: "")

    expect(consent).not_to be_valid
    expect(consent.errors.attribute_names).to contain_exactly(:data_subject, :consent_given_on, :scope)
  end

  it "rejects an unknown relationship to the matter" do
    consent.subject_role = "neighbor"

    expect(consent).not_to be_valid
  end

  it "rejects a withdrawal dated before the consent" do
    consent.withdrawn_on = consent.consent_given_on - 1.day

    expect(consent).not_to be_valid
    expect(consent.errors.attribute_names).to eq([:withdrawn_on])
  end

  it "is withdrawn once it has a withdrawal date" do
    expect { consent.withdrawn_on = Date.new(2026, 11, 20) }.to change(consent, :withdrawn?).from(false).to(true)
  end
end
