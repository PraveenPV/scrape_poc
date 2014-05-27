require 'rubygems'
require 'mechanize'
require 'json'
require 'yaml'
#require 'pry'

# string helpers
class String
    def ustrip
        self.gsub(/[[:space:]]/, ' ').strip
    end
end

class File
  def tail(n)
    buffer = 1024
    idx = (size - buffer).abs
    chunks = []
    lines = 0

    begin
      seek(idx)
      chunk = read(buffer)
      lines += chunk.count("\n")
      chunks.unshift chunk
      idx -= buffer
    end while lines < ( n + 1 ) && pos != 0

    tail_of_file = chunks.join('')
    ary = tail_of_file.split(/\n/)
    lines_to_return = ary[ ary.size - n, ary.size - 1 ]
  end
end


def read_table(table)
    table.search('tr').map do |row|
        row.search('td').map do |col|
            col.text.strip
        end
    end
end

def extract_label_values(nodes, label_selector, value_selector)
    kv = nodes.map do |node|
        label = node.at(label_selector)
        value = node.at(value_selector)
        [label.text.ustrip, value.text.ustrip]
    end
    Hash[kv]
end

def cached_get(agent, url)
    key = Digest::SHA1.hexdigest url
    cache_file = "_cache/#{key}.html"
    if File.exists? cache_file
        puts "[CACHED] #{url}"
        cached = YAML.load_file(cache_file)
        uri, response, body, code = cached
        page = Mechanize::Page.new(uri, response, body, code, agent)
        agent.send(:add_to_history, page)
    else
        Dir.mkdir("_cache") unless Dir.exist?("_cache")
        puts "[FETCH] #{url}"
        page = agent.get(url)
        to_cache = [page.uri, page.response, page.body, page.code]
        File.open(cache_file, 'w') { |file| file.write(to_cache.to_yaml) }
    end
    page
end

def setup_agent
    agent = Mechanize.new
    agent.user_agent_alias = 'Windows IE 9'
    #proxy if required
    #agent.set_proxy '204.228.129.46', 8080
    agent
end
