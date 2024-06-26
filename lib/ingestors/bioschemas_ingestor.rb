require 'open-uri'
require 'tess_rdf_extractors'

module Ingestors
  class BioschemasIngestor < Ingestor
    attr_reader :verbose

    def self.config
      {
        key: 'bioschemas',
        title: 'Bioschemas',
        user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:102.0) Gecko/20100101 Firefox/102.0'
      }
    end

    def read(source_url)
      sitemap_regex = nil
      @verbose = false
      sources = if source_url.downcase.match?(/sitemap(.*)?.xml\Z/)
                  @messages << "\nParsing sitemap: #{source_url}\n"
                  urls = SitemapParser.new(source_url, {
                                      recurse: true,
                                      url_regex: sitemap_regex,
                                      headers: { 'User-Agent' => config[:user_agent] }
                                    }).to_a.uniq.map(&:strip)
                  @messages << " - #{urls.count} URLs found"
                  urls
                else
                  [source_url]
                end

      provider_events = []
      provider_materials = []
      totals = Hash.new(0)
      sources.each do |url|
        source = open_url(url)
        next unless source

        sample = source.read(256)&.strip
        next unless sample

        format = sample.start_with?('[') || sample.start_with?('{') ? :jsonld : :rdfa
        source.rewind
        source = source.read
        events = Tess::Rdf::EventExtractor.new(source, format, base_uri: url).extract do |p|
          convert_params(p)
        end
        courses = Tess::Rdf::CourseExtractor.new(source, format, base_uri: url).extract do |p|
          convert_params(p)
        end
        course_instances = Tess::Rdf::CourseInstanceExtractor.new(source, format, base_uri: url).extract do |p|
          convert_params(p)
        end
        learning_resources = Tess::Rdf::LearningResourceExtractor.new(source, format, base_uri: url).extract do |p|
          convert_params(p)
        end
        totals['Events'] += events.count
        totals['Courses'] += courses.count
        totals['CourseInstances (without Course)'] += course_instances.count
        totals['LearningResources'] += learning_resources.count
        if verbose
          puts "Events: #{events.count}"
          puts "Courses: #{courses.count}"
          puts "CourseInstances (without Course): #{course_instances.count}"
          puts "LearningResources: #{learning_resources.count}"
        end

        deduplicate(events + courses + course_instances).each do |event|
          provider_events << event
        end

        deduplicate(learning_resources).each do |material|
          provider_materials << material
        end
      end

      if totals.keys.any?
        @messages << "\nBioschemas summary:\n"
        totals.each do |type, count|
          @messages << " - #{type}: #{count}"
        end

      end

      deduplicate(provider_events).each do |event_params|
        add_event(event_params)
      end

      deduplicate(provider_materials).each do |material_params|
        add_material(material_params)
      end
    end

    # If duplicate resources have been extracted, prefer ones with the most metadata.
    def deduplicate(resources)
      return [] unless resources.any?

      puts "De-duplicating #{resources.count} resources" if verbose
      hash = {}
      scores = {}
      resources.each do |resource|
        resource_url = resource[:url]
        puts "  Considering: #{resource_url}" if verbose
        if hash[resource_url]
          score = metadata_score(resource)
          # Replace the resource if this resource has a higher metadata score
          puts "    Duplicate! Comparing #{score} vs. #{scores[resource_url]}" if verbose
          if score > scores[resource_url]
            puts '    Replacing resource' if verbose
            hash[resource_url] = resource
            scores[resource_url] = score
          end
        else
          puts '    Not present, adding' if verbose
          hash[resource_url] = resource
          scores[resource_url] = metadata_score(resource)
        end
      end

      puts "#{hash.values.count} resources after de-duplication" if verbose

      hash.values
    end

    # Score based on number of metadata fields available
    def metadata_score(resource)
      score = 0
      resource.each_value do |value|
        score += 1 unless value.nil? || value == {} || value == [] || (value.is_a?(String) && value.strip == '')
      end

      score
    end

    def convert_params(params)
      params[:description] = convert_description(params[:description]) if params.key?(:description)

      params
    end
  end
end
