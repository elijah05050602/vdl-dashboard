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

RSpec.describe DemoData::LawFirm::MatterTemplatesSeeder do
  include_context "with basic seed data"

  subject(:seeder) { described_class.new(basic_seed_data) }

  let(:identifiers) { seeder.templates.pluck("identifier") }

  before { seeder.seed! }

  it "creates one template project per matter kind" do
    expect(Project.templated.pluck(:identifier)).to match_array(identifiers)
  end

  it "creates the intake checklist wiki page for every template" do
    Project.templated.each do |project|
      expect(project.wiki.pages.pluck(:title)).to include("Intake checklist")
    end
  end

  it "anchors each plan on one manually scheduled step and chains the others to it" do
    Project.templated.each do |project|
      manual = project.work_packages.where(schedule_manually: true)
      expect(manual.count).to eq(1)

      leaves = project.work_packages
                      .where(schedule_manually: false)
                      .where.not(id: WorkPackage.where.not(parent_id: nil).select(:parent_id))
      expect(leaves).to all(satisfy { |wp| Relation.follows.exists?(from_id: wp.id) })
    end
  end

  it "keeps every successor on or after the soonest start allowed by its predecessor" do
    Relation.follows.includes(:from, :to).find_each do |relation|
      expect(relation.successor.start_date).to eq(relation.successor_soonest_start)
    end
  end

  it "gives every work package dates" do
    expect(WorkPackage.where(start_date: nil).or(WorkPackage.where(due_date: nil))).to be_empty
  end

  it "uses statuses allowed by each type's workflow" do
    allowed = Source::SeedDataLoader.get_data.lookup("workflows").to_h do |workflow|
      [basic_seed_data.find_reference(workflow["type"]).id,
       basic_seed_data.find_references(workflow["statuses"]).map(&:id)]
    end

    WorkPackage.find_each do |work_package|
      expect(allowed.fetch(work_package.type_id)).to include(work_package.status_id), work_package.subject
    end
  end

  it "does not recreate templates on a second run" do
    expect { described_class.new(basic_seed_data).seed! }.not_to change(Project, :count)
  end

  describe "a matter created from a template" do
    let(:admin) { seeder.admin_user }
    let(:template) { Project.find_by!(identifier: "template-contract-review") }
    let(:matter) do
      Projects::CopyService
        .new(source: template, user: admin)
        .call(target_project_params: { name: "Acme supply agreement", identifier: "acme-supply" },
              only: %w[work_packages wiki queries],
              send_notifications: false)
        .result
    end
    let(:anchor) { matter.work_packages.find_by!(subject: "Contract received from client") }
    let(:new_start) { anchor.start_date + 14.days }

    before do
      WorkPackages::UpdateService
        .new(user: admin, model: anchor)
        .call(start_date: new_start, due_date: new_start)
    end

    it "copies the plan, the views and the intake checklist" do
      expect(matter.work_packages.count).to eq(template.work_packages.count)
      expect(matter.queries.pluck(:name)).to contain_exactly("Matter plan", "Deadlines and hearings")
      expect(matter.wiki.pages.pluck(:title)).to include("Intake checklist")
    end

    it "moves every following step when the first milestone moves" do
      template_dates = template.work_packages.to_h { [it.subject, it.start_date] }

      matter.work_packages.where.not(id: anchor.id).find_each do |work_package|
        expect(work_package.start_date).to be > template_dates.fetch(work_package.subject), work_package.subject
      end

      Relation.follows.where(from_id: matter.work_packages.select(:id)).find_each do |relation|
        expect(relation.successor.start_date).to eq(relation.successor_soonest_start)
      end
    end
  end
end
