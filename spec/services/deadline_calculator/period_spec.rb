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

RSpec.describe DeadlineCalculator::Period do
  describe ".all" do
    it "loads valid periods with unique keys and known groups" do
      periods = described_class.all

      expect(periods).to all(be_valid)
      expect(periods.map(&:key)).to eq(periods.map(&:key).uniq)
      expect(periods.map(&:group).uniq - described_class.groups.keys).to be_empty
      expect(periods.map(&:rule)).to all(be_present)
      expect(periods.map(&:key)).not_to include(described_class::CUSTOM_KEY)
    end

    it "includes the common Philippine periods" do
      expect(described_class.find("answer").days).to eq(30)
      expect(described_class.find("notice_of_appeal").days).to eq(15)
      expect(described_class.find("rule_45").days).to eq(15)
      expect(described_class.find("rule_65").days).to eq(60)
      expect(described_class.find("nlrc_appeal").days).to eq(10)
    end
  end

  describe ".custom" do
    it "accepts a name and a whole number of days" do
      period = described_class.custom(name: " Comment ", days: "10", rule: "Resolution of Nov 20")

      expect(period).to be_valid
      expect(period).to be_custom
      expect(period.label).to eq("Comment (Resolution of Nov 20)")
    end

    it "rejects a missing name or a bad number of days" do
      expect(described_class.custom(name: "", days: "10", rule: "")).not_to be_valid
      expect(described_class.custom(name: "Comment", days: "ten", rule: "")).not_to be_valid
      expect(described_class.custom(name: "Comment", days: "0", rule: "")).not_to be_valid
      expect(described_class.custom(name: "Comment", days: "1.5", rule: "")).not_to be_valid
      expect(described_class.custom(name: "Comment", days: "99999", rule: "")).not_to be_valid
    end
  end
end
