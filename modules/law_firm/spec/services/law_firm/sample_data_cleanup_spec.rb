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

require "rails_helper"

RSpec.describe LawFirm::SampleDataCleanup do
  shared_let(:admin) { create(:admin) }

  subject(:cleanup) { described_class.new(user: admin) }

  it "removes only the stock demo and developer projects" do
    demo = create(:project, identifier: "demo-project", name: "Demo project")
    dev_large = create(:project, identifier: "dev-large")
    create(:project, identifier: "dev-large-child", parent: dev_large)
    matter = create(:project, identifier: "santos-annulment")

    result = cleanup.call.result

    expect(result[:removed_projects]).to contain_exactly(demo.name, dev_large.name)
    expect(Project.pluck(:identifier)).to eq [matter.identifier]
  end

  it "locks the sample users but keeps real users and the acting admin" do
    sample = create(:user, login: "reader", mail: "reader@example.net")
    lawyer = create(:user, mail: "lawyer@vdl.ph")

    expect(cleanup.call.result[:locked_users]).to eq ["reader"]
    expect(sample.reload).to be_locked
    expect(lawyer.reload).to be_active
    expect(admin.reload).to be_active
  end
end
