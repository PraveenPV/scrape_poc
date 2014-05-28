require 'uri'
require 'typhoeus'
require 'nokogiri'

CACHE_DIR = '_tycache'

class Cache
    def initialize
        Dir.mkdir(CACHE_DIR) unless Dir.exist?(CACHE_DIR)
    end

    def cachekey(request)
        Digest::SHA1.hexdigest request.url
    end

    def get(request)
        key=cachekey(request)
        cache_file = "#{CACHE_DIR}/#{key}.html"
        if File.exists? cache_file
            puts "[CACHED] #{request.url}"
            cached = YAML.load_file(cache_file)
            return cached
        end
    end

    def set(request, response)
        key=cachekey(request)
        cache_file = "#{CACHE_DIR}/#{key}.html"
        File.open(cache_file, 'w') { |file| file.write(response.to_yaml) }
    end
end

class ScrapedPage
    def initialize(html, url)
        @doc = Nokogiri::HTML(html)
        @uri = URI(url)
    end

    def at(selector)
        @doc.at_css(selector)
    end

    def search(selector)
        @doc.css(selector)
    end

    def uri
        return @uri
    end
end
