require 'rubygems'
require 'mechanize'
require 'json'
require 'yaml'
#require 'pry'
require 'csv'
require 'set'
require 'optparse'

require_relative 'parse_helper'
require_relative 'models'

URL = 'http://www.perfectgame.org/Articles/View.aspx?article=9322'
PROFILE_URL_FORMAT = 'http://www.perfectgame.org/Players/Playerprofile.aspx?ID='
SELECTOR_HEADER = '#ContentPlaceHolder1_prof_whitelink div.prof_right_of_main_image > div:nth-child(1) > div:nth-child(2)'
SELECTOR_INFO_TABLE = '#ContentPlaceHolder1_prof_whitelink div.main_prof_bio_section > div > table'
SELECTOR_COMMITMENT = '#ctl00_ContentPlaceHolder1_RadPanelBar1 li.rpFirst b'
BROKEN_URL_CACHE = "_cache/%_broken_urls.txt"

$options = {
    :output => 'perfectgame.csv',
    :header => true,
    :start_id => 105895,
    :end_id => 357201
}

optparse = OptionParser.new do |opts|
    opts.banner = "Scraper for perfectgame.org"

    opts.on("-o", "--output OUTPUT", "output csv file path") do |output|
        $options[:output] =  output
    end

    opts.on("-n", "--no-header", "don't add csv file header") do
        $options[:header] = false
    end

    opts.on("-s", "--start-id START_ID", "starting id") do |start_id|
        $options[:start_id] = start_id.to_i
    end

    opts.on("-e", "--end-id END_ID", "ending id") do |end_id|
        $options[:end_id] = end_id.to_i
    end
end

optparse.parse!

def parse_height(height)
    if height.include? '-'
        v = height.split('-')
        "#{v[0]}'#{v[1]}"
    else
        ""
    end
end

def extract_state(str)
    state = str.strip.split(' ')[0] if str
    return state.strip if state
end

def parse_player_details(page)
    player = Player.new
    header = page.at(SELECTOR_HEADER)
    return if !header
    head_spans = header.search('span')

    player.player_id = page.uri.to_s.split('=')[1].to_i

    full_name = head_spans[0].text.strip
    player.first_name = full_name.split()[0]
    player.last_name = full_name.split()[1]

    player.position = head_spans[2].text.strip
    player.sport = 'Baseball'
    player.gender = 'M'

    table = read_table(page.search(SELECTOR_INFO_TABLE))
    table_hash = Hash[table.map { |row| [row[0], row[2]] }]

    player.bats_throws = table_hash["Bats/Throws"]
    player.team = table_hash["Summer Team"]

    if table_hash["HS"]
        graduate_info = table_hash["HS"].split('|')
        player.highschool = graduate_info[0].strip if graduate_info[0]
        player.year = graduate_info[1].gsub(/[^\d]+/, '').strip if graduate_info[1]
    end

    if table_hash["Hometown"]
        place = table_hash["Hometown"].split(',')
        player.city = place[0].strip if place[0]
        player.state = extract_state(place[1]) if place[1]
    end

    if table_hash["Ht/Wt"]
        ht_wt = table_hash["Ht/Wt"].split(',')
        player.height = parse_height(ht_wt[0].strip) if ht_wt[0]
        player.weight = ht_wt[1].sub('lbs.','').strip if ht_wt[1]
    end

    commit_heading = page.at(SELECTOR_COMMITMENT)

    if commit_heading && commit_heading.text.strip == 'College Commitment(s)'
        n = commit_heading.next_element
        while n && (n.name == 'br' || n.name == 'text')
            n = n.next_element
        end
        if n && n.name == 'a'
            player.commit_status = n.next.inner_text.strip
        end
    end

    player
end

def crawl_player_page(agent, url)
    page = cached_get(agent, url)
    obj = parse_player_details(page)
end


def crawl_index_page(agent, url)
    page = cached_get(agent, url)
    links = page.links_with(:href => /Playerprofile.aspx?/)
    results = []
    # l = links.first
    # results.push(crawl_player_page(agent, page.uri.merge(l.uri).to_s))
    results = links.map do |l|
        crawl_player_page(agent, page.uri.merge(l.uri).to_s)
    end
    dump_to_csv(results)
end

def load_broken_urls()
    broken_urls = Set.new
    if File.exists? $broken_url_file
        File.open($broken_url_file).each do |line|
            broken_urls << line.strip
        end
    end
    return broken_urls
end

def fetch_last_id()
    if File.exists?($options[:output])
        File.open($options[:output]) do |f|
            lines = f.tail(1)
            if lines.length > 0 && lines[0].include?(',')
                lines[0].split(',')[0].to_i
            end
        end
    end
end

def crawl_profiles(agent)
    from = $options[:start_id]
    to = $options[:end_id]
    results = []
    header = $options[:header]
    broken_urls = load_broken_urls()
    error_cache = File.open($broken_url_file, 'a')
    last_id = fetch_last_id()
    from = last_id if last_id
    for id in from..to
        url = "#{PROFILE_URL_FORMAT}#{id}"
        begin
            next if broken_urls.include? url
            r = crawl_player_page(agent, url)
            results.push(r) if r
            if results.length > 10
                dump_to_csv(results, header)
                header = false
                results = []
            end
        rescue Mechanize::ResponseCodeError
            puts "^^^ FAILED"
            error_cache.puts url
            error_cache.flush
        end
    end
    if results.length > 0
        dump_to_csv(results, header)
    end
    puts "Result in #{$options[:output]}"
end

def dump_to_csv(results, header=false)
    mode = 'a'
    CSV.open($options[:output], mode) do |csv|
        headers = results.first.headers()
        csv << headers if header
        results.each do |o|
          csv << o.to_a(headers)
        end
    end
end

$broken_url_file = BROKEN_URL_CACHE.sub('%', $options[:output].downcase.sub('.csv',''))
agent = setup_agent
#crawl_index_page(agent, URL)
crawl_profiles(agent)

