require 'rubygems'
require 'mechanize'
require 'json'
require 'yaml'
#require 'pry'
require 'csv'
require 'set'

require_relative 'parse_helper'
require_relative 'models'


# URL = "http://softballshowcase.com/player/fastpitch-softball-recruiting-profile/index.php?id=15581"
URL = "http://softballshowcase.com/player/search.php"
SELECTOR_HEADER = "#body-container > div:nth-child(4) > div.well-light.hidden-phone > div:nth-child(1) > div > h1"
SELECTOR_INFO_ROW = "#body-container > div:nth-child(4) > div.well-light.hidden-phone > div:nth-child(2) > div.span7.offset1 > div:nth-child(1)"
SELECTOR_CONTENT_BOX_TITLE = ".span4 .content_title"
SELECTOR_COMMIT_STATUS = "#body-container > div:nth-child(4) > div.well-light.hidden-phone > div:nth-child(2) > div.span7.offset1 > div:nth-child(2) > div > div > span.bold.font_m"

def with_box(title_nodes, title_to_find)
    title_node = title_nodes.find { |x| x.text.strip == title_to_find }
    yield(title_node.next_element) if title_node
end

def parse_player_details(page)
    player = Player.new

    player.sport = 'Softball'
    player.gender = 'F'

    header = page.at(SELECTOR_HEADER)
    full_name = header.child.text.ustrip
    player.first_name = full_name.split(' ')[0]
    player.last_name = full_name.split(' ')[1]

    place = header.at('small').text.ustrip
    player.city = place[0..-4]
    player.state = place[-2..-1] || ""

    info_nodes = page.at(SELECTOR_INFO_ROW).search('div.pad_5')
    info_hash = extract_label_values(info_nodes,
                                        'span.muted',
                                        'span.bold')
    player.year = info_hash['High School Class']
    player.bats_throws = info_hash['Bats/Throws']
    player.position = info_hash['Positions']
    player.height = info_hash['Height']

    box_titles = page.search(SELECTOR_CONTENT_BOX_TITLE)
    with_box(box_titles, "Travel/Club Info") do |n|
        player.team = n.at('div.bold').text.ustrip \
                        if n.at('div.bold')
        player.jersey_number = n.at('div:nth-child(3)').text.split('#')[1] \
                                    if n.at('div:nth-child(3)')
    end

    with_box(box_titles, "School Info") do |n|
        player.highschool = n.at('div.bold').text.ustrip \
                                if n.at('div.bold')
        player.gpa = n.at('div:nth-child(4)').text.strip.sub('GPA: ', '') \
                        if n.at('div:nth-child(4)') \
                                && n.at('div:nth-child(4)').text.include?('GPA:')
    end

    player.commit_status = page.at(SELECTOR_COMMIT_STATUS).text.strip

    player
end

def crawl_player_page(agent, url)
    page = cached_get(agent, url)
    obj = parse_player_details(page)
end

def crawl_index_page(agent, url)
    is_first = true
    processed_urls = Set.new
    while true
        page = cached_get(agent, url)
        links = page.links_with(:href => /player\/profile\.php\?id\=/)
        results = links.map do |l|
            profile_url = page.uri.merge(l.uri).to_s
            if !processed_urls.include? profile_url
                processed_urls << profile_url
                crawl_player_page(agent, profile_url)
            end
        end
        results = results.reject{ |x| x.nil? }
        if results.length > 0
            dump_to_csv(results, !is_first)
            is_first = false
        end
        next_link = page.links_with(:href => /search\.php/, :text => 'Next').first
        if next_link
            url = page.uri.merge(next_link.uri).to_s
        else
            break
        end
    end
    puts '[DONE] Results in softballshowcase.csv'
end

def dump_to_csv(results, append=false)
    mode = if append then 'a' else 'w' end
    CSV.open("softballshowcase.csv", mode) do |csv|
        headers = results.first.headers()
        csv << headers if !append
        results.each do |o|
          csv << o.to_a(headers)
        end
    end
end

agent = setup_agent
crawl_index_page(agent, URL)
#crawl_player_page(agent, URL)

