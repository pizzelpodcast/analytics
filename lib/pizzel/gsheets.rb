# frozen_string_literal: true

require "google_drive"
require "pizzel/episodes"

module Pizzel
  class GSheets
    WORKSHEET_TITLE = "Raw"

    HEADER_ROW = %w{ ep day date hits }.freeze

    attr_reader :config, :episodes

    Config = Struct.new(:analytics_id, :service_account_key, keyword_init: true) do
      def initialize(*args)
        super
        %i{ analytics_id service_account_key }.each do |k|
          raise ArgumentError, "missing #{k}" unless self[k]
        end
      end

      # Converts service_account_key to a proper path
      def service_account_key_path
        if service_account_key.start_with?("/", "~")
          return File.expand_path(service_account_key)
        end

        Pizzel::USER_DIR.join(service_account_key)
      end
    end

    def initialize(config, episodes)
      @config = Config.new(config).freeze
      @episodes = episodes
    end

    def test
      !!sheet.worksheet_by_title(WORKSHEET_TITLE)
    end

    def sync
      ws = sheet.worksheet_by_title(WORKSHEET_TITLE)
      ws.delete_rows(1, ws.num_rows)

      rows = [HEADER_ROW]

      episodes.each_by_number.sort_by(&:first).each do |ep, downloads|
        downloads.sort_by(&:first).each_with_index do |(date, count), i|
          rows << [ep, i + 1, date, count]
        end
      end

      ws.update_cells(1, 1, rows)

      ws.save
    end

    private

    def session
      @session =
        GoogleDrive::Session.from_service_account_key(
          config.service_account_key_path.to_s
        )
    end

    def sheet
      @sheet ||= session.spreadsheet_by_key(config.analytics_id)
    end
  end
end
