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
  module Invoices
    class PDF < ::Exports::PDF::Common::View
      LOGO_PATH = Rails.root.join("app/assets/images/law_firm/vdl-mark-charcoal.png")
      CHARCOAL = "3A3A3A"
      MUTED = "6B6B6B"
      RULE = "C8C8C8"
      STAMP = "B42318"
      FOOTER_HEIGHT = 46
      FEE_KINDS = %w[time fee].freeze

      attr_reader :invoice

      def initialize(invoice, draft: false, reprint: false)
        super(I18n.locale)
        @invoice = invoice
        @draft = draft
        @reprint = reprint
        self.title = document_title
      end

      def options
        @options ||= { page_size: "A4", margin: [36, 40, 36 + FOOTER_HEIGHT, 40] }
      end

      def render
        draw_header
        draw_parties
        draw_lines
        draw_totals
        draw_payment_notes
        draw_schedule
        draw_page_decorations
        document.render
      end

      def filename
        @draft ? "draft-#{invoice.period_from}-#{invoice.period_to}.pdf" : invoice.filename
      end

      private

      def seller
        @seller ||= invoice.seller.to_h.stringify_keys
      end

      def vat_registered?
        invoice.vat_rate.present?
      end

      def t(key, **)
        I18n.t("law_firm_invoices.pdf.#{key}", **)
      end

      def document_title
        @draft ? t(:draft_title) : seller["title"].presence || t(:default_title)
      end

      def draw_header # rubocop:disable Metrics/AbcSize
        top = cursor
        logo_width = 0
        if LOGO_PATH.exist?
          image LOGO_PATH.to_s, at: [0, top], height: 62
          logo_width = 70
        end

        bounding_box([logo_width, top], width: (bounds.width * 0.58) - logo_width) do
          apply_font(font_style: :bold, size: 12)
          text seller["registered_name"].to_s, color: CHARCOAL
          apply_font(font_style: :normal, size: 8.5)
          text seller["trade_name"], color: MUTED if seller["trade_name"].present?
          text seller["address"].to_s, color: CHARCOAL
          text tin_statement, color: CHARCOAL
          contact = [seller["phone"], seller["email"]].compact_blank.join("  ·  ")
          text contact, color: MUTED if contact.present?
        end
        left_bottom = cursor

        bounding_box([bounds.width * 0.6, top], width: bounds.width * 0.4) do
          if @reprint
            apply_font(font_style: :bold, size: 11)
            text t(:reprint), align: :right, color: STAMP
          end
          apply_font(font_style: :bold, size: 16)
          text document_title, align: :right, color: CHARCOAL
          move_down 2
          apply_font(font_style: :bold, size: 13)
          text number_label, align: :right, color: @draft ? MUTED : STAMP
          apply_font(font_style: :normal, size: 9)
          text "#{t(:date)}: #{format_date(invoice.issued_on)}", align: :right
        end

        move_cursor_to [left_bottom, cursor].min
        move_down 10
        stroke_color RULE
        stroke_horizontal_rule
        move_down 10
      end

      def tin_statement
        label = vat_registered? ? t(:vat_reg_tin) : t(:non_vat_reg_tin)
        "#{label} #{seller['tin']}"
      end

      def number_label
        @draft ? t(:no_number) : "No. #{invoice.number}"
      end

      def draw_parties # rubocop:disable Metrics/AbcSize
        top = cursor
        bounding_box([0, top], width: bounds.width * 0.6) do
          small_caption t(:billed_to)
          apply_font(font_style: :bold, size: 10)
          text invoice.client_name.to_s
          apply_font(font_style: :normal, size: 9)
          text invoice.client_address.to_s
          text "TIN: #{invoice.client_tin.presence || '—'}"
        end
        left_bottom = cursor

        bounding_box([bounds.width * 0.62, top], width: bounds.width * 0.38) do
          small_caption t(:matter)
          apply_font(font_style: :normal, size: 9)
          text invoice.project&.name.to_s
          move_down 4
          small_caption t(:period)
          apply_font(font_style: :normal, size: 9)
          text "#{format_date(invoice.period_from)} – #{format_date(invoice.period_to)}"
        end

        move_cursor_to [left_bottom, cursor].min
        move_down 14
      end

      def small_caption(caption)
        apply_font(font_style: :bold, size: 7.5)
        text caption.upcase, color: MUTED, character_spacing: 0.5
        move_down 2
      end

      def draw_lines # rubocop:disable Metrics/AbcSize
        rows = [[t(:description), t(:quantity), t(:unit_cost), t(:amount)]]
        grouped_lines.each do |heading, lines|
          rows << [{ content: heading, colspan: 4, font_style: :bold, text_color: MUTED, size: 8 }]
          lines.each { |line| rows << line_row(line) }
        end

        apply_font(font_style: :normal, size: 9)
        table(rows, header: true, width: bounds.width,
                    column_widths: { 0 => bounds.width - 265, 1 => 90, 2 => 85, 3 => 90 },
                    cell_style: { size: 9, padding: [4, 5], borders: [:bottom], border_color: RULE }) do |tbl|
          tbl.row(0).font_style = :bold
          tbl.row(0).background_color = "F2F2F2"
          tbl.columns(1..3).align = :right
        end
        move_down 10
      end

      def grouped_lines
        lines = invoice.lines.map(&:stringify_keys)
        {
          t(:section_professional_fees) => lines.select { |line| FEE_KINDS.include?(line["kind"]) },
          t(:section_disbursements) => lines.select { |line| line["kind"] == "disbursement" }
        }.reject { |_, group| group.empty? }
      end

      def line_row(line)
        description = line["description"].to_s
        description += " (#{t(:vat_exempt_marker)})" if vat_registered? && !line["vatable"]
        quantity = [number(line["quantity"], strip: true), line["unit"]].compact_blank.join(" ")
        [description, quantity, money(line["unit_cost"]), money(line["amount"])]
      end

      def draw_totals # rubocop:disable Metrics/AbcSize
        rows = []
        if vat_registered?
          rows << [t(:vatable_sales), money(invoice.vatable_sales)]
          rows << [t(:vat_exempt_sales), money(invoice.vat_exempt_sales)]
          rows << [t(:zero_rated_sales), money(invoice.zero_rated_sales)]
          rows << [t(:vat_amount, rate: percent(invoice.vat_rate)), money(invoice.vat_amount)]
          rows << [{ content: t(:total_vat_inclusive), font_style: :bold },
                   { content: money(invoice.total_amount), font_style: :bold }]
        else
          rows << [{ content: t(:total_sales), font_style: :bold }, { content: money(invoice.total_amount), font_style: :bold }]
        end

        if invoice.ewt_amount.to_d.positive?
          rows << [t(:less_ewt, rate: percent(invoice.ewt_rate), base: money(invoice.ewt_base)), "(#{money(invoice.ewt_amount)})"]
          rows << [{ content: t(:amount_due), font_style: :bold }, { content: money(invoice.amount_due), font_style: :bold }]
        end

        width = 290
        bounding_box([bounds.width - width, cursor], width:) do
          table(rows, width:, column_widths: { 1 => 100 },
                      cell_style: { size: 9, padding: [3, 5], borders: [] }) do |tbl|
            tbl.columns(1).align = :right
            tbl.row(rows.length - 1).borders = [:top]
            tbl.row(rows.length - 1).border_color = CHARCOAL
          end
        end
        move_down 12
      end

      def draw_payment_notes # rubocop:disable Metrics/AbcSize
        notes = []
        notes << t(:ewt_note) if invoice.ewt_amount.to_d.positive?
        notes << seller["payment_terms"] if seller["payment_terms"].present?
        notes.concat(Array(seller["payment_instructions"]))
        return if notes.empty?

        apply_font(font_style: :normal, size: 8.5)
        notes.each { |note| text note, color: CHARCOAL }
      end

      def draw_schedule # rubocop:disable Metrics/AbcSize
        details = invoice.details.map(&:stringify_keys)
        return if details.empty?

        start_new_page
        apply_font(font_style: :bold, size: 11)
        text t(:schedule_title, number: @draft ? t(:no_number) : invoice.number)
        move_down 6

        rows = [[t(:date), t(:person), t(:activity), t(:description), t(:hours_or_units), t(:amount)]]
        details.each { |detail| rows << detail_row(detail) }

        apply_font(font_style: :normal, size: 8)
        table(rows, header: true, width: bounds.width,
                    column_widths: { 0 => 58, 1 => 85, 2 => 85, 3 => bounds.width - 355, 4 => 52, 5 => 75 },
                    cell_style: { size: 8, padding: [3, 4], borders: [:bottom], border_color: RULE }) do |tbl|
          tbl.row(0).font_style = :bold
          tbl.row(0).background_color = "F2F2F2"
          tbl.columns(4..5).align = :right
        end
      end

      def detail_row(detail)
        [
          format_date(detail["date"]),
          detail["person"].to_s,
          detail["activity"].to_s,
          detail["description"].to_s,
          number(detail["quantity"], strip: true),
          money(detail["amount"])
        ]
      end

      def draw_page_decorations # rubocop:disable Metrics/AbcSize
        repeat(:all, dynamic: true) do
          draw_stamp(t(:draft_watermark)) if @draft
          draw_stamp(t(:cancelled_watermark)) if invoice.cancelled?

          bounding_box([0, -6], width: bounds.width, height: FOOTER_HEIGHT) do
            stroke_color RULE
            stroke_horizontal_rule
            move_down 4
            apply_font(font_style: :normal, size: 7.5)
            text footer_registration, color: MUTED
            if @draft
              apply_font(font_style: :bold, size: 8)
              text t(:not_valid_for_input_tax), color: STAMP
            end
            apply_font(font_style: :normal, size: 7.5)
            text t(:page, page: page_number, total: page_count), align: :right, color: MUTED
          end
        end
      end

      def footer_registration
        [
          "#{t(:accn)}: #{seller['acknowledgement_certificate_no']}",
          "#{t(:date_issued)}: #{seller['acknowledgement_certificate_date']}",
          "#{t(:series_range)}: #{seller['series_range']}"
        ].join("   ·   ")
      end

      def draw_stamp(label) # rubocop:disable Metrics/AbcSize
        transparent(0.12) do
          rotate(30, origin: [bounds.width / 2, bounds.height / 2]) do
            apply_font(font_style: :bold, size: 72)
            fill_color STAMP
            draw_text label, at: [(bounds.width - width_of(label)) / 2, bounds.height / 2]
            fill_color "000000"
          end
        end
      end

      def money(value)
        "₱ #{number(value)}"
      end

      def number(value, strip: false)
        decimal = BigDecimal(value.to_s.presence || "0")
        formatted = ActiveSupport::NumberHelper.number_to_rounded(decimal, precision: 2, delimiter: ",")
        strip ? formatted.delete_suffix(".00") : formatted
      end

      def percent(rate)
        value = ActiveSupport::NumberHelper.number_to_rounded(BigDecimal(rate.to_s) * 100,
                                                              precision: 2, strip_insignificant_zeros: true)
        "#{value}%"
      end

      def format_date(value)
        return "" if value.blank?

        date = value.is_a?(String) ? Date.iso8601(value) : value
        date.strftime("%b %d, %Y")
      end
    end
  end
end
