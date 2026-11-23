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

RSpec.describe DataPrivacy::AuditEvent do
  let(:user) { create(:user, firstname: "Maria", lastname: "Santos") }
  let(:project) { create(:project, name: "People v. Reyes") }

  it "keeps the user's and the matter's names when they are deleted later" do
    event = create(:data_privacy_audit_event, user:, project:)
    user.delete
    project.delete

    event = described_class.find(event.id)
    expect([event.user_label, event.project_label]).to eq(["Maria Santos", "People v. Reyes"])
  end

  it "cannot be edited once recorded" do
    event = create(:data_privacy_audit_event, user:)

    expect { event.update!(action: "change") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
