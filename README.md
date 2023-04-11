Small project for getting useful data from ITL2023 competition

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
