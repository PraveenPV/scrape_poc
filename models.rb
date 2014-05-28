
class Player
    attr_accessor :player_id, :first_name, :last_name, :position,
                    :sport, :gender, :bats_throws, :team, :highschool,
                    :year, :city, :state, :height, :weight, :commit_status,
                    :video_url, :gpa, :jersey_number
    @@headers_cached = nil
    def headers()
        return @@headers_cached if @@headers_cached
        filter = /\w+=/
        all_methods = self.methods.map { |v| v.to_s }
        h = all_methods.select do |x|
            x.end_with?('=') && x =~ filter
        end.map do |x|
            x.sub('=','')
        end
        @@headers_cached = h
        return h
    end

    def to_a()
        headers = @@headers_cached
        headers.map{ |v| send("#{v}") }
    end
end
