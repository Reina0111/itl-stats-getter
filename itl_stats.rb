require 'optparse'
require 'open-uri'
require 'json'

MODE_OPTIONS = ["users", "stats"]
STATS_KIND_OPTIONS = ["passes", "levels", "levelstop", "points", "averagebyregion"]
USERS_KIND_OPTIONS = ["regions", "list", "listbyregions", "listbyregionstop"]
ALL_KINDS = USERS_KIND_OPTIONS + STATS_KIND_OPTIONS

@levels = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]

def parseOptions
  options = {}
  begin
    OptionParser.new do |opt|
      opt.on('-m', '--mode mode', "Available options: #{MODE_OPTIONS.join(', ')}") { |o| options[:mode] = o if MODE_OPTIONS.include?(o.downcase) }
      opt.on('-k', '--kind kind', 
        "Kind of user list you want to get or kind of stats you want to check. Available options: #{ALL_KINDS.join(', ')}") { |o| options[:kind] = o.downcase if ALL_KINDS.include?(o.downcase) }
      opt.on('-f', '--file file', "Name of file you want to use as input") { |o| options[:file] = o }
      opt.on('-i', '--id id', "Id of itl user you want to check stats for") { |o| options[:id] = o }
      opt.on('-n', '--nick nick', "Nick of itl user you want to check stats for") { |o| options[:nick] = o }
      opt.on('-r', '--regions regions', "List of regions - used for 'users' mode and 'list' kind") { |o| options[:regions] = o.split(',').map { |r| r.strip() } }
    end.parse!
  rescue OptionParser::InvalidOption => e
    puts e
    options = {}
  end

  if USERS_KIND_OPTIONS.include?(options[:kind])
    options[:mode] = "users"
  elsif STATS_KIND_OPTIONS.include?(options[:kind])
    options[:mode] = "stats"
  else
    options = {}
  end

  options
end

def get_leaderboard(my_list = nil)
  list = nil
  URI.open('https://itl2023.groovestats.com/api/entrant/leaderboard') do |uri|
      list = JSON.parse(uri.read)["data"]["leaderboard"]
  end

  if my_list
    ids = my_list.map { |user| user["id"] }
    list = list.select { |user| ids.include?(user["id"]) }
  end

  list
end

def parse_file_or_get_user(file, id, nick)
  list = []
  return get_user(id, nick) if !file

  File.open(file).each do |line|
      list << JSON.parse(line)
  end

  list
end

def get_user(id, nick)
  return nil if !id && !nick

  if !id
      list = nil
      URI.open('https://itl2023.groovestats.com/api/entrant/leaderboard') do |uri|
          list = JSON.parse(uri.read)["data"]["leaderboard"]
      end
      user = list.select { |user| user["name"] == nick }.first
      if user
          id = user["id"]
      else
          puts "Nie znaleziono gracza - upewnij się, że podałeś taki sam nick jaki widnieje na stronie itl2023.groovestats.com"
          return []
      end
  end
  
  user = nil

  URI.open("https://itl2023.groovestats.com/api/entrant/#{id}") do |uri|
      user = JSON.parse(uri.read)["data"]
  end

  [user]
end

def users_mode(options)
    
  users_list = parse_file_or_get_user(options[:file], options[:id], options[:nick])
  users_list_ids = users_list&.map { |user| user["gs_id"] }

  case options[:kind]
  when "regions"
    list = get_leaderboard()
    list.map! { |user| { gs_id: user["membersId"], id: user["id"], name: user["name"] } }

    existing_ids = list.map { |user| user[:gs_id] }
    if users_list_ids
      existing_ids = existing_ids.select { |id| !users_list_ids.include?(id) }
    end
    full_list = []
    regions = []
    
    while existing_ids.count > 0
      list_to_check = list.select { |user| existing_ids.include?(user[:gs_id]) }
      existing_ids = []
  
      list_to_check.each do |user|
        begin
          URI.open("https://groovestats.com/index.php?page=profile&id=#{user[:gs_id]}") do |uri|
            page = uri.read
            region = page[page.index('href="?page=regions')..-1]
            region = region[region.index('>')+1..region.index('<')-1]
            user[:region] = region
            regions << region
          end
          full_list << user
          puts user.to_json
        rescue Net::OpenTimeout
          existing_ids << user[:gs_id]
        end
      end
    end    
  when "list"
    regions = options[:regions]

    region_list = users_list&.select { |user| regions.include?(user["region"]) } if regions
    region_list&.each do |user|
      puts user.to_json
    end
  when "listbyregions"
    regions = users_list&.map { |user| user["region"] }.uniq
    region_length = regions.map { |region| region.length }.max
    regions.map! { |region| { region: region, users: users_list&.select { |user| user["region"] == region }.count } }

    regions.sort_by { |r| [-r[:users], r[:region]] }.each do |region|
      puts "#{region[:region].rjust(region_length, " ")} - #{region[:users].to_s.rjust(3, " ")} users"
    end
  when "listbyregionstop"
    list = get_leaderboard(users_list)
    ids = list.select { |user| user["totalPass"].to_i + user["totalFc"].to_i + user["totalFec"].to_i + user["totalQuad"].to_i + user["totalQuint"].to_i >= 75 }.map { |user| user["id"] }
    users_list = users_list&.select { |user| ids.include?(user["id"]) }
    regions = users_list&.map { |user| user["region"] }.uniq
    region_length = regions.map { |region| region.length }.max
    regions.map! { |region| { region: region, users: users_list&.select { |user| user["region"] == region }.count } }

    regions.sort_by { |r| [-r[:users], r[:region]] }.each do |region|
      puts "#{region[:region].rjust(region_length, " ")} - #{region[:users].to_s.rjust(3, " ")} users"
    end
  end
end

def stats_mode(options)
  user_list = parse_file_or_get_user(options[:file], options[:id], options[:nick])
  multi = user_list.count > 1

  if multi
    case options[:kind]
    when "levels", "levelstop"
      puts "#{" " * 16}#{@levels.map { |lvl| "| " + lvl.to_s.rjust(3, " ") + " " }.join }"
      puts "#{"-" * 16}#{@levels.map { |_| "+" + "-"*5 }.join}"
    when "points"
      puts "#{" "*16}|ranking| total"
    end
  end

  if options[:kind] == "averagebyregion"
    average_by_region(user_list)
    return nil
  end

  user_list.each do |user|
    user = get_user(user["id"], nil)[0] if !user["entrant"]
    case options[:kind]
    when "passes"
      songs = user["topScores"]
      sum = songs.sum { |song| song["totalPasses"].to_i }
      puts "#{user["entrant"]["name"].to_s.rjust(15, " ")} - passes: #{sum.to_s.rjust(3, " ")}"
    when "levels"
      user_songs = user["topScores"]
      songs = user["charts"]
      user_songs.map! { |u_song| songs.find { |song| song["hash"] == u_song["chartHash"] } }
      grouped_levels = user_songs.group_by { |song| song["meter"] }
      
      if multi
        levels_count = @levels.map { |lvl| grouped_levels[lvl] ? grouped_levels[lvl].count : 0 }
        puts "#{user["entrant"]["name"].to_s[0..14].rjust(15, " ")} | #{levels_count.map { |lvl| lvl.to_s.rjust(3, " ") }.join(" | ")}"
      else
        puts "Songs by level for user #{user["entrant"]["name"]}"
        puts grouped_levels.sort.map { |k, v| "Level #{k.to_s.rjust(2, " ")}: #{v.count.to_s.rjust(3, " ")}" }
      end
    when "levelstop"
      user_songs = user["topScores"].sort_by { |song| song["points"] }.reverse[0..74]
      songs = user["charts"]
      user_songs.map! { |u_song| songs.find { |song| song["hash"] == u_song["chartHash"] } }
      grouped_levels = user_songs.group_by { |song| song["meter"] }
      
      if multi
        levels_count = @levels.map { |lvl| grouped_levels[lvl] ? grouped_levels[lvl].count : 0 }
        puts "#{user["entrant"]["name"].to_s[0..14].rjust(15, " ")} | #{levels_count.map { |lvl| lvl.to_s.rjust(3, " ") }.join(" | ")}"
      else
        puts "Top 75 songs by level for user #{user["entrant"]["name"]}"
        puts grouped_levels.sort.map { |k, v| "Level #{k.to_s.rjust(3, " ")}: #{v.count.to_s.rjust(3, " ")}" }
      end
    when "points"
      if multi
        puts "#{user["entrant"]["name"].to_s[0..14].rjust(15, " ")} |#{user["entrant"]["rankingPoints"].to_s.rjust(7, " ") }|#{user["entrant"]["totalPoints"].to_s.rjust(7, " ") }"
      else
        puts "          User: #{user["entrant"]["name"].to_s[0..14].rjust(15, " ")}"
        puts "Ranking Points: #{user["entrant"]["rankingPoints"].to_s[0..14].rjust(15, " ")}"
        puts "  Total Points: #{user["entrant"]["totalPoints"].to_s[0..14].rjust(15, " ")}"
      end
    end
  end
end

def average_by_region(users_list)
  regions = users_list.map { |user| user["region"] }.uniq
  region_length = regions.map { |region| region.length }.max
  regions.map! { |region| { region: region, users: users_list&.select { |user| user["region"] == region } } }

  scores_length = 0
  median_length = 0
  regions.each do |region|
    scores = get_leaderboard(region[:users]).map { |user| user["rankingPoints"].to_i }.sort
    scores_avg = scores.sum / region[:users].count.to_f

    len = scores.count
    region[:median] = ((scores[(len - 1) / 2] + scores[len / 2]) / 2.0).round(2)
    region[:scores] = (scores.sum / scores.count).round(2)
    scores_length = [scores_length, region[:scores].to_s.length].max
    median_length = [median_length, region[:median].to_s.length].max
  end

  regions.sort_by { |r| [-r[:scores], r[:region]] }.each do |region|
    puts "#{region[:region].rjust(region_length, " ")} - #{region[:scores].to_s.rjust(scores_length, " ")} Avg | #{region[:median].to_s.rjust(median_length, " ")} Median"
  end
end

def main
  options = parseOptions()

  return if !options || options == {}

  case options[:mode]
  when "users"
    users_mode(options)
  when "stats"
    stats_mode(options)
  end
end

main