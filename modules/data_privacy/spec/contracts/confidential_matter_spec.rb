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

RSpec.describe "Confidential matters" do
  shared_let(:project) { create(:project, confidential: true, public: false) }
  shared_let(:project_admin) do
    create(:user, member_with_permissions: { project => %i[view_project edit_project share_work_packages
                                                            view_work_packages view_shared_work_packages] })
  end
  shared_let(:admin) { create(:admin) }

  describe Projects::UpdateContract do
    it "refuses making a confidential matter public" do
      project.public = true
      contract = described_class.new(project, admin)

      expect(contract.validate).to be(false)
      expect(contract.errors.symbols_for(:public)).to include(:confidential_matter)
    end

    it "lets only an admin remove the confidential mark" do
      project.confidential = false

      expect(described_class.new(project, project_admin).validate).to be(false)
      expect(described_class.new(project, admin).validate).to be(true)
    end

    it "lets a project admin mark a matter confidential" do
      other = create(:project, confidential: false)
      member = create(:user, member_with_permissions: { other => %i[view_project edit_project] })
      other.confidential = true

      expect(described_class.new(other, member).validate).to be(true)
    end
  end

  describe Shares::WorkPackages::CreateContract do
    it "refuses sharing a work package of a confidential matter" do
      work_package = create(:work_package, project:)
      role = create(:work_package_role, permissions: %i[view_work_packages])
      share = Member.new(entity: work_package, project:, principal: create(:user))
      share.member_roles.build(role:)
      contract = described_class.new(share, project_admin)

      expect(contract.validate).to be(false)
      expect(contract.errors.symbols_for(:base)).to include(:confidential_matter)
    end
  end
end
