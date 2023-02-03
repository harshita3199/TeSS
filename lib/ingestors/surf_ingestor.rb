require 'open-uri'
require 'csv'
require 'nokogiri'
require 'active_support/core_ext/hash'

module Ingestors
  class SurfIngestor < Ingestor
    def self.config
      {
        key: 'surf_event',
        title: 'Surf Events API',
        category: :events
      }
    end

    def read(url)
      begin
        process_surf(url)
      rescue Exception => e
        @messages << "#{self.class.name} failed with: #{e.message}"
      end

      # finished
      nil
    end

    private
    def process_surf(url)
      Hash.from_xml(Nokogiri::XML(URI.open(url)).to_s)['sitemapindex']['sitemap'].each do |page|
        Hash.from_xml(Nokogiri::XML(URI.open(page['loc'])).to_s)['urlset']['url'].each do |event_page|
          next unless event_page['loc'].include?('/en/agenda/')

          sleep(1)
          data_json = Nokogiri::HTML5.parse(URI.open(event_page['loc'])).css('script[type="application/ld+json"]')
          next unless data_json.length > 0

          data = JSON.parse(data_json.first.text)
          begin
            # create new event
            event = Event.new

            # extract event details from
            attr = data['@graph'].first
            event.title = convert_title attr['name']
            event.url = attr['url']&.strip
            event.description = convert_description attr['description']
            event.start = attr['startDate']
            event.end = attr['endDate']
            event.set_default_times
            event.venue = if attr['location'].is_a?(Array)
                            attr['location'].join(' - ')
                          else
                            attr['location']
                          end
            event.source = 'SURF'
            event.online = true
            event.timezone = 'Amsterdam'

            # add event to events array
            add_event(event)
            @ingested += 1
          rescue Exception => e
            @messages << "Extract event fields failed with: #{e.message}"
            Sentry.capture_exception(e)
          end
        end
      end
    end
  end
end
