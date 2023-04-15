Small project for getting useful data from ITL2023 competition

# itl_stats.rb
Single file for all options
Usage: itl_stats [options]
    -m, --mode mode                  Available options: users, stats (default - users)
    -k, --kind kind                  Kind of user list you want to get or kind of stats you want to check. 
                                     Available options for users: regions, list, listbyregions
                                     Available options for stats: passes, levels, levelstop, points
    -f, --file file                  Name of file you want to use as input
    -i, --id id                      Id of itl user you want to check stats for
    -n, --nick nick                  Nick of itl user you want to check stats for
    -r, --regions regions            List of regions - used when mode and kind are set to 'users' and 'list'

## Example of uses
`ruby itl_stats.rb -m users -k regions`
Outputs list of all itl users in format `{"gs_id":174237, "id":604, "name":"Reina0111", "region":"Poland"}`

`ruby itl_stats.rb -m users -k list -r "Poland, United Kingdom" -f users.txt`
Outputs list of itl users from selected regions from list given as file input

`ruby itl_stats.rb -m users -k listByRegions -f users.txt`
Outputs number of players from given file divided by regions

`ruby itl_stats.rb -m stats -k passes -i 604`
Outputs total passes of player with given id
`ruby itl_stats.rb -m stats -k passes -f users.txt`
Outputs total passes for all players from list given as file input

`ruby itl_stats.rb -m stats -k levels -nick Reina0111`
Outputs number of passed songs on each level for given player
`ruby itl_stats.rb -m stats -k levels -f users.txt`
Outputs number of passed songs on each level for all players from list given as file input

`ruby itl_stats.rb -m stats -k levelsTop --nick Reina0111`
Outputs top 75 passed songs divided by level for given player
`ruby itl_stats.rb -m stats -k levelsTop -f users.txt`
Outputs top 75 passed songs divided by level for all players from list given as file input

`ruby itl_stats.rb -m stats -k points -i 604`
Outputs total points and ranking points for player with given id
`ruby itl_stats.rb -m stats -k points -f users.txt`
Outputs total points and ranking points for all players from list given as file input


# users_list.rb
This file is used to get list of all users participating in competition from https://itl2023.groovestats.com page with additional info about users regions

# total_passes.rb
This file is used to get additional stats
Usage:
if you want to check multiple people at once you can use
`ruby total_passes.rb auto USER_LIST_TXT STAT_TO_CHECK`

if you want to check single person stats you can use
`ruby total_passes.rb [id|nick] [USER_ID|USER_NICK] STAT_TO_CHECK`

available STAT_TO_CHECK options:
`totalPasses` shows total passes of all songs (if song was played 3 times it will be counted 3 times)
`songsByLevel` shows number of songs passed on each difficulty level
`songsByLevelTop` shows number of songs passed on each difficulty level from user's top 75
`points` shows ranking and total points
