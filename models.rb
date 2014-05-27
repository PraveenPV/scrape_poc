
class Player
    attr_accessor :player_id, :first_name, :last_name, :position,
                    :sport, :gender, :bats_throws, :team, :highschool,
                    :year, :city, :state, :height, :weight, :commit_status,
                    :video_url, :gpa, :jersey_number

    def headers()
        filter = /\w+=/
        all_methods = self.methods.map { |v| v.to_s }
        all_methods.select do |x|
            x.end_with?('=') && x =~ filter
        end.map do |x|
            x.sub('=','')
        end
    end

    def to_a(headers)
        headers.map{ |v| send("#{v}") }
    end
end
