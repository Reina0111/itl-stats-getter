require 'open-uri'
require 'json'

@auto = false
@types = ["totalPasses", "songsByLevel", "songsByLevelTop"]

# TODO poprawić łapanie argumentów
def check_args(args)
    if args.count == 3 && args[0] == "auto" && @types.include?(args[2])
        @auto = true
        return true
    end

    if args.count < 3 || !["id", "nick"].include?(args[0]) || !@types.include?(args[2])
        puts "Usage:
        if you want to check stats of multiple people at once "
    elsif args[0] == "id" && args[1].to_i == 0
        puts "id musi być liczbą"
    else
        return true
    end
    
    false
end

def get_user(type, value)
    if type == "nick"
        list = nil
        URI.open('https://itl2023.groovestats.com/api/entrant/leaderboard') do |uri|
            list = JSON.parse(uri.read)["data"]["leaderboard"]
        end
        user = list.select { |user| user["name"] == value }.first
        if user
            value = user["id"]
        else
            puts "Nie znaleziono gracza - upewnij się, że podałeś taki sam nick jaki widnieje na stronie itl2023.groovestats.com"
            return nil
        end
    end
    
    user = nil
    # tutaj value powinno już być idkiem
    URI.open("https://itl2023.groovestats.com/api/entrant/#{value}") do |uri|
        user = JSON.parse(uri.read)["data"]
    end

    user
end

def check_stats(user, type)
    case type
    when "totalPasses"
        songs = user["topScores"]
        sum = songs.sum { |song| song["totalPasses"].to_i }
        puts "#{user["entrant"]["name"].to_s.rjust(10, " ")} - totalPasses: #{sum.to_s.rjust(3, " ")}"
    when "songsByLevel"
        user_songs = user["topScores"]
        songs = user["charts"]
        user_songs.map! { |u_song| songs.find { |song| song["hash"] == u_song["chartHash"] } }
        grouped_levels = user_songs.group_by { |song| song["meter"] }
        puts "Songs by level for user #{user["entrant"]["name"]}"
        puts grouped_levels.sort.map { |k, v| "Level #{k.to_s.rjust(2, " ")}: #{v.count.to_s.rjust(3, " ")}" }
    when "songsByLevelTop"
        user_songs = user["topScores"].sort_by { |song| song["points"] }.reverse[0..74]
        songs = user["charts"]
        user_songs.map! { |u_song| songs.find { |song| song["hash"] == u_song["chartHash"] } }
        grouped_levels = user_songs.group_by { |song| song["meter"] }
        puts "Top 75 songs by level for user #{user["entrant"]["name"]}"
        puts grouped_levels.sort.map { |k, v| "Level #{k.to_s.rjust(2, " ")}: #{v.count.to_s.rjust(3, " ")}" }
    end
end

def main
    return false if !check_args(ARGV)

    users_list = []
    if @auto
        users_list = []
        File.open(ARGV[1]).each do |line|
            users_list << JSON.parse(line)
        end
        users_list.map! { |user| { type: "id", value: user["id"] } }
    else
        users_list = [{ type: ARGV[0], value: ARGV[1] }]
    end

    users_list.each do |u|
        user = get_user(u[:type], u[:value])
        check_stats(user, ARGV[2])
    end
end

main