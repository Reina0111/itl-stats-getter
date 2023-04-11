require 'open-uri'
require 'json'

list = nil
URI.open('https://itl2023.groovestats.com/api/entrant/leaderboard') do |uri|
    list = JSON.parse(uri.read)["data"]["leaderboard"]
end

list.map! { |user| { gs_id: user["membersId"], id: user["id"], name: user["name"] } }
# , totalPoints: user["totalPoints"], 
# rankingPoints: user["rankingPoints"], totalPass: user["totalPass"], totalFc: user["totalFc"], 
# totalFec: user["totalFec"], totalQuad: user["totalQuad"], totalQuint: user["totalQuint"] } }

users_list = []
File.open('users.txt').each do |line|
    users_list << JSON.parse(line)
end
users_list_ids = users_list.map { |user| user["gs_id"] }
# puts users_list

regions = ["Poland"]

# scrappowanie regionów ze strony groovestats
# error_ids = list.map { |user| user[:gs_id] }.select { |id| !users_list_ids.include?(id) }
# full_list = []

# while error_ids.count > 0
#     list_to_check = list.select { |user| error_ids.include?(user[:gs_id]) }
#     error_ids = []

#     list_to_check.each do |user|
#         begin
#             URI.open("https://groovestats.com/index.php?page=profile&id=#{user[:gs_id]}") do |uri|
#                 page = uri.read
#                 region = page[page.index('href="?page=regions')..-1]
#                 region = region[region.index('>')+1..region.index('<')-1]
#                 user[:region] = region
#                 regions << region
#             end
#             # puts user[:name]
#             full_list << user
#             File.write('users.txt', "#{user}\n", mode: 'a')
#         rescue Net::OpenTimeout
#             error_ids << user[:gs_id]
#         end
#     end
# end

# puts regions.uniq
# puts full_list


# lista europejska
eu_list = users_list.select { |user| regions.include?(user["region"]) }
eu_ids = eu_list.map { |user| user["gs_id"]}
eu_list.each do |eu_user|
    list.select { |u| u[:gs_id] == eu_user["gs_id"] }.first[:region] = eu_user["region"]
end
puts list.select { |user| eu_ids.include?(user[:gs_id]) }.map { |user| { id: user[:id], name: user[:name], region: user[:region] }}