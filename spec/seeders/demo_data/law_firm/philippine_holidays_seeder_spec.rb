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

RSpec.describe DemoData::LawFirm::PhilippineHolidaysSeeder do
  include_context "with basic seed data"

  subject(:seeder) { described_class.new(basic_seed_data) }

  before do
    allow(Rails.env).to receive(:test?).and_return(false)
  end

  it "adds the Philippine holidays as non-working days" do
    seeder.seed!

    expect(NonWorkingDay.find_by(date: Date.new(2026, 6, 12))&.name).to eq("Independence Day")
    expect(NonWorkingDay.find_by(date: Date.new(2027, 12, 30))&.name).to eq("Rizal Day")
    expect(NonWorkingDay.count).to eq(seeder.holidays.size)
  end

  it "keeps non-working days that already exist" do
    create(:non_working_day, date: Date.new(2026, 12, 25), name: "Pasko")

    expect { seeder.seed! }.to change(NonWorkingDay, :count).by(seeder.holidays.size - 1)
    expect(NonWorkingDay.find_by(date: Date.new(2026, 12, 25)).name).to eq("Pasko")
  end

  it "is not applicable once every holiday exists" do
    seeder.seed!
    expect(described_class.new(basic_seed_data)).not_to be_applicable
  end
end
