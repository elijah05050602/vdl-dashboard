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

module LawFirm
  class InvoiceSettings
    PLACEHOLDER = /\A\s*\z|\A\[.*\]\z|\A[0\-\s]+\z/

    def initialize(data)
      @data = data.deep_stringify_keys
    end

    def title
      string("title").presence || "SERVICE INVOICE"
    end

    %w[registered_name trade_name tin address phone email payment_terms
       acknowledgement_certificate_no acknowledgement_certificate_date].each do |key|
      define_method(key) { string(key) }
    end

    def payment_instructions
      Array(@data["payment_instructions"]).map(&:to_s).compact_blank
    end

    def number_prefix
      string("number_prefix")
    end

    def number_digits
      [@data["number_digits"].to_i, 1].max
    end

    def series_start
      [@data.fetch("series_start", 1).to_i, 1].max
    end

    def series_end
      @data["series_end"].presence&.to_i
    end

    def format_number(serial)
      "#{number_prefix}#{serial.to_s.rjust(number_digits, '0')}"
    end

    def series_range
      [format_number(series_start), series_end && format_number(series_end)].compact.join(" to ")
    end

    def disbursements_vatable?
      @data.fetch("disbursements_vatable", true) != false
    end

    def ewt_rates
      Array(@data["ewt_rates"]).map { |rate| BigDecimal(rate.to_s) }.select(&:positive?)
    end

    def missing_details
      %w[registered_name tin address acknowledgement_certificate_no].select do |key|
        string(key).match?(PLACEHOLDER)
      end
    end

    def ready_to_issue?
      missing_details.empty?
    end

    def seller_snapshot
      %w[title registered_name trade_name tin address phone email payment_terms
         acknowledgement_certificate_no acknowledgement_certificate_date].index_with { |key| public_send(key) }
        .merge("series_range" => series_range, "payment_instructions" => payment_instructions)
    end

    private

    def string(key)
      @data[key].to_s.strip
    end
  end
end
