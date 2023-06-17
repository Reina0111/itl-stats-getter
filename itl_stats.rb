require 'optparse'
require 'open-uri'
require 'json'

require_relative 'regions.rb'

MODE_OPTIONS = ["users", "stats"]
STATS_KIND_OPTIONS = ["passes", "levels", "levelstop", "points", "averagebyregion", "rivals"]
USERS_KIND_OPTIONS = ["regions", "list", "listbyregions", "listbyregionstop"]
ALL_KINDS = USERS_KIND_OPTIONS + STATS_KIND_OPTIONS

@levels = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
CHUNK_SIZES = 35

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
  
  ids = id&.split(',')
  nicks = nick&.split(',')
  ids.each do |i|
    list += get_user(i)
  end if ids

  nicks.each do |n|
    list += get_user(nil, n)
  end if nicks

  return list.uniq if !file

  File.open(file).each do |line|
      list << JSON.parse(line)
  end

  list.uniq
end

def get_user(id = nil, nick = nil)
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

  begin
    sleep 0.2
    URI.open("https://itl2023.groovestats.com/api/entrant/#{id}") do |uri|
      user = JSON.parse(uri.read)["data"]
    end
  rescue Net::OpenTimeout
    STDERR.puts "timeout for player #{id}... trying again..."
    get_user(id)
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

    i = 1
    regions.sort_by { |r| [-r[:users], r[:region]] }.each do |region|
      if REGION_FLAGS[region[:region].to_sym] != 'US'.tr('A-Z', "\u{1F1E6}-\u{1F1FF}")
        puts "#{i.to_s.rjust(2, " ")}. #{region[:region].rjust(region_length, " ")} - #{region[:users].to_s.rjust(3, " ")} users"
      end
      i += 1
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
    end
  end

  case options[:kind] 
  when "averagebyregion"
    average_by_region(user_list)
    return nil
  when "points"
    points(user_list)
    return nil
  when "passes"
    user_list = get_leaderboard(user_list)
    passes(user_list)
    return nil
  when "rivals"
    rivals(user_list, options[:regions])
    return nil
  end

  user_list = get_leaderboard(user_list)
  user_list.each do |user|
    user = get_user(user["id"], nil)[0] if !user["entrant"]
    case options[:kind]
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
    end
  end
end

def passes(user_list)
  list = []

  if user_list.count > CHUNK_SIZES
    lists = user_list.each_slice(CHUNK_SIZES).to_a
    threads = []
    (0..lists.length-1).each do |i|
      l = lists[i]
      threads << Thread.new(i, l) do
        STDERR.puts "New thread#{i} started with #{l.length} users to check"
        Thread.current[:output] = []
        l.each_with_index do |u, index|
          user = nil
          while user == nil
            user = get_user(u["id"], nil)[0] if !u["entrant"]
          end
          songs = user["topScores"]
          sum = songs.sum { |song| song["totalPasses"].to_i }
          Thread.current[:output] << { name: user["entrant"]["name"], passes: sum }
          if (index + 1) % 10 == 0
            STDERR.puts "thread#{i} finished checking #{index + 1}/#{CHUNK_SIZES} users"
          end
        end
      end
    end

    threads.each do |t|
      t.join
      list += t[:output]
    end
  else
    user_list.each_with_index do |u, i|
      user = get_user(u["id"], nil)[0] if !u["entrant"]
      songs = user["topScores"]
      sum = songs.sum { |song| song["totalPasses"].to_i }
      list << { name: user["entrant"]["name"], passes: sum }
      if i % 50 == 0
        STDERR.puts "#{(list.length.to_f / user_list.length * 100).round(2)}% completed"
      end
    end
  end

  length = list.map { |u| u[:name].length }.max
  list.sort_by { |u| -u[:passes] }.each do |u|
    puts "#{u[:name].to_s.rjust(length, " ")} - passes: #{u[:passes].to_s.rjust(3, " ")}"
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

def points(user_list)
  list = get_leaderboard(user_list)
  use_flags = user_list.map { |user| user["region"] }.uniq.count > 1
  i = 1
  no_lenght = list.count.to_s.length
  if list.count > 1
    puts "#{" "*21}|ranking| total"
    list.each do |user|
      flag = get_flag(user_list.find { |el| el["id"] == user["id"] })
      puts "#{"`" if use_flags}#{i.to_s.rjust(no_lenght, " ")}. #{user["name"].to_s[0..9].rjust(10, " ")} |#{user["rankingPoints"].to_s.rjust(7, " ") }|#{user["totalPoints"].to_s.rjust(7, " ") } #{"`#{flag}" if use_flags}"
      i += 1
    end
  else
    user = list.first
    puts "          User: #{user["name"].to_s[0..14].rjust(15, " ")}"
    puts "Ranking Points: #{user["rankingPoints"].to_s[0..14].rjust(15, " ")}"
    puts "  Total Points: #{user["totalPoints"].to_s[0..14].rjust(15, " ")}"
  end
end

def rivals(user_list, kind)
  kind_type = kind.first if kind.class == Array
  kind_type = "ex" if !["ex", "points"].include?(kind_type)

  case kind_type
  when "ex"
    kind = :difference
  when "points"
    kind = :difference_p
  end

  if user_list.count != 2
    puts "W trybie rivals musisz podać dokładnie 2 graczy"
    return nil
  end

  # songs list [[first user songs (hashes only)], [second user songs (hashes only)]]
  songs = user_list.map { |u| u["topScores"].map { |song| song["chartHash"] } }

  # common songs list (hashes only)
  songs = (songs.first & songs.last)

  # common songs list (max_points, song level, title, hash)
  songs_info = user_list.first["charts"]
    .select { |song| songs.include?(song["hash"]) }
    .map { |song| { max_points: [song["points"], 1].max, meter: song["meter"], name: song["titleRomaji"].length > 0 ? song["titleRomaji"] : song["title"], hash: song["hash"] } }

  ids = user_list.map { |u| u["entrant"]["id"] }
  # adding users scores to common songs list (ex scores and points)
  user_list.each do |user|
    songs_info.each do |song|
      score = user["topScores"].select { |s| s["chartHash"] == song[:hash] }.first
      song[user["entrant"]["id"]] = score["ex"].to_f / 100
      song["#{user["entrant"]["id"]}_p"] = score["points"]
    end
  end

  # adding differences to common songs list (ex scores and points)
  songs_info.map { |song| song[:difference] = (song[ids.first] - song[ids.last]).round(2) }
  songs_info.map { |song| song[:difference_p] = ((song["#{ids.first}_p"].to_f - song["#{ids.last}_p"])/song[:max_points]*100).round(2) }

  better_scores_count = songs_info.select { |song| song[ids.first] >= song[ids.last] }.count

  puts "Compare scores #{user_list.first["entrant"]["name"]} to #{user_list.last["entrant"]["name"]} by #{kind_type}"
  puts "  diff |  lvl | title"
  songs_info.sort_by { |song| -song[kind] }.each_with_index do |song, index|
    if index == better_scores_count && better_scores_count != 0
      puts "-"*35
    end

    next if kind_type == "points" && song[:max_points] == 1

    puts "#{song[kind].to_s.rjust(6, " ")} | [#{song[:meter].to_s.rjust(2, "0")}] | #{song[:name][0..19]}"
  end
end

def get_flag(user)
  region = user["region"]
  REGION_FLAGS[region.to_sym]
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