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

require_relative "../../../spec_helper"

RSpec.describe BasicData::Costs::LawFirmBillingSeeder do
  subject(:seeder) { described_class.new(seed_data) }

  let(:seed_data) { Source::SeedData.new({}) }
  let(:config) do
    LawFirm::BillingConfig.new(
      "default_project_modules" => %w[costs budgets],
      "billing_roles" => [
        { "name" => "Partner", "hourly_rate" => 8000, "permissions" => :partner },
        { "name" => "Paralegal", "hourly_rate" => 1500, "permissions" => :timekeeper }
      ],
      "non_billable_activities" => ["Administrative (non-billable)", "Pro bono (non-billable)"],
      "expense_types" => [
        { "name" => "Acceptance fee", "unit" => "peso", "unit_plural" => "pesos", "rate" => 1, "default" => true },
        { "name" => "Appearance fee", "unit" => "hearing", "unit_plural" => "hearings", "rate" => 5000 }
      ]
    )
  end

  before do
    allow(LawFirm::BillingConfig).to receive(:current).and_return(config)
    create(:time_entry_activity, name: "Legal research")
  end

  it "creates the billing roles with billing permissions" do
    seeder.seed!

    expect(ProjectRole.find_by(name: "Partner").permissions)
      .to include(:log_time, :view_hourly_rates, :edit_budgets, :save_cost_reports)
    expect(ProjectRole.find_by(name: "Paralegal").permissions)
      .to include(:log_own_time, :view_budgets)
    expect(ProjectRole.find_by(name: "Paralegal").permissions).not_to include(:view_hourly_rates)
  end

  it "gives billing roles matter permissions even without a Member role to copy from" do
    seeder.seed!

    expect(ProjectRole.find_by(name: "Paralegal").permissions)
      .to include(:view_work_packages, :edit_work_packages, :add_work_package_comments)
  end

  it "creates the non-billable activities" do
    seeder.seed!

    expect(TimeEntryActivity.pluck(:name))
      .to contain_exactly("Legal research", "Administrative (non-billable)", "Pro bono (non-billable)")
  end

  it "creates the expense types with their rates" do
    seeder.seed!

    expect(CostType.find_by(name: "Acceptance fee")).to have_attributes(default: true, for_all_projects: true)
    expect(CostType.find_by(name: "Appearance fee").current_rate).to eq 5000
  end

  it "switches on time and budgets for new matters" do
    seeder.seed!

    expect(Setting.default_projects_modules).to include("costs", "budgets")
  end

  it "leaves settings alone that are set through the environment" do
    allow(Settings::Definition[:default_projects_modules]).to receive(:writable?).and_return(false)

    expect { seeder.seed! }.not_to raise_error
    expect(Setting.default_projects_modules).not_to include("budgets")
  end

  it "creates public billable and non-billable cost reports" do
    seeder.seed!

    non_billable_ids = TimeEntryActivity.where("name LIKE ?", "%(non-billable)").pluck(:id).map(&:to_s)
    billable = CostReport.find_by(name: "Billable hours by matter")

    expect(billable).to have_attributes(public: true, project_id: nil, unit_id: -1,
                                        pivot_rows: %w[project_id user_id], pivot_columns: %w[tyear tmonth])
    expect(billable.query.filters.map { [it.name, it.operator, it.values] })
      .to eq([[:activity_id, "!", non_billable_ids]])
    expect(CostReport.find_by(name: "Billable amounts by matter (before tax)").unit_id).to eq 0
    expect(CostReport.find_by(name: "Non-billable time by person").query.filters.first.operator).to eq "="
  end

  it "adds nothing twice when run again" do
    seeder.seed!

    expect { described_class.new(seed_data).seed! }
      .not_to change { [ProjectRole.count, TimeEntryActivity.count, CostType.count, CostRate.count, CostReport.count] }
  end
end
