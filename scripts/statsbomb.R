# Libraries
library(dplyr)
library(tidyr)
library(jsonlite)
library(StatsBombR)
library(feather)
library(stringi)
library(tidyr)
library(lubridate)

# Read in functions ####
get_and_merge_nicknames <- function(events, Match, get.lineupsFree, cleanlineups) {
  # Get player lineups for the match
  lineup <- get.lineupsFree(Match)
  
  # Clean and process the lineup data
  lineup <- cleanlineups(lineup)
  lineup <- lineup %>%
    dplyr::mutate(player_nickname = ifelse(is.na(player_nickname), player_name, player_nickname)) %>%
    dplyr::select(player.id = player_id, player.name = player_nickname) %>%
    dplyr::group_by(player.id) %>%
    dplyr::slice(1) %>%
    dplyr::ungroup()
  
  # Prepare other_lineup dataframe for recipient data
  other_lineup <- lineup %>%
    dplyr::select(pass.recipient.id = player.id, pass.recipient.name = player.name)
  
  # Merge lineup data with events data for player names
  events <- events %>%
    select(-player.name) %>%
    dplyr::left_join(lineup, by = c("player.id" = "player.id"))
  
  # Merge lineup data with events data for pass recipient names
  events <- events %>%
    select(-pass.recipient.name) %>%
    dplyr::left_join(other_lineup, by = c("pass.recipient.id" = "pass.recipient.id"))
  
  return(events)
}

adjust_timestamps <- function(events) {
  # Convert the timestamp to seconds
  dataframe <- events
  dataframe$timestamp_seconds <- as.numeric(hms(dataframe$timestamp))
  
  # Calculate the max timestamp for each period in each match
  period_max_times <- dataframe %>%
    group_by(match_id, period) %>%
    summarise(period_max_time = max(timestamp_seconds), .groups = 'drop')
  
  # Calculate the cumulative max timestamp for each period in each match
  cumulative_max_times <- period_max_times %>%
    group_by(match_id) %>%
    arrange(match_id, period) %>%
    mutate(cumulative_max_time = cumsum(period_max_time) - period_max_time) %>%
    select(-period_max_time) %>%
    ungroup()
  
  # Inspect cumulative_max_times
  print(head(cumulative_max_times))
  
  # 4. Join this back to the original dataframe
  dataframe <- left_join(dataframe, cumulative_max_times, by = c("match_id", "period"))
  
  # Inspect the joined dataframe to check if 'cumulative_max_time' is present
  print(head(dataframe))
  print(colnames(dataframe))  # Check if 'cumulative_max_time' is a column name
  
  # Adjust timestamps
  dataframe <- dataframe %>%
    mutate(adjusted_timestamp_seconds = timestamp_seconds + cumulative_max_time) %>%
    ungroup()
  
  return(dataframe)
}

add_opposing_team_column <- function(events_df) {
  # Assuming each row in events_df has 'match_id' and 'team.name'
  
  # Create a list to store the opposing team names
  opposing_teams <- vector("list", length = nrow(events_df))
  
  # For each match, find the unique teams and determine the opposing team for each event
  unique_matches <- unique(events_df$match_id)
  for (match_id in unique_matches) {
    # Filter events for this match
    match_events <- events_df[events_df$match_id == match_id, ]
    
    # Find the two unique teams
    teams <- unique(match_events$team.name)
    
    # Assign the opposing team for each event
    opposing_teams[events_df$match_id == match_id] <- ifelse(match_events$team.name == teams[1], teams[2], teams[1])
  }
  
  # Add the opposing team names to the original dataframe
  events_df$opposing.team.name <- unlist(opposing_teams)
  
  return(events_df)
}

add_order_column <- function(dataframe) {
  # Adding an order column to the dataframe
  dataframe$order <- seq_len(nrow(dataframe))
  
  # Returning the modified dataframe
  return(dataframe)
}

label_position_categories <- function(dataframe) {
  # Ensure tidyr is loaded
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    install.packages("tidyr")
    library(tidyr)
  }
  
  # Create a temporary dataframe to determine home and away teams for each match
  home_away_df <- dataframe %>%
    dplyr::group_by(match_id) %>%
    dplyr::summarise(home_team = first(team.name),
                     away_team = first(opposing.team.name))
  
  # Join this information back to the original dataframe
  dataframe <- merge(dataframe, home_away_df, by = "match_id")
  
  # Label lineup formation columns for home and away teams
  dataframe$formation_h <- ifelse(dataframe$team.name == dataframe$home_team &
                                    (dataframe$type.name == 'Starting XI' | dataframe$type.name == 'Tactical Shift'), dataframe$tactics.formation, NA)
  dataframe <- dataframe %>% dplyr::group_by(match_id) %>% tidyr::fill(formation_h)
  
  dataframe$formation_a <- ifelse(dataframe$team.name == dataframe$away_team &
                                    (dataframe$type.name == 'Starting XI' | dataframe$type.name == 'Tactical Shift'), dataframe$tactics.formation, NA)
  dataframe <- dataframe %>% dplyr::group_by(match_id) %>% tidyr::fill(formation_a)
  
  # Determine the relevant formation based on the team
  dataframe$relevant.formation <- ifelse(dataframe$team.name == dataframe$home_team, dataframe$formation_h, dataframe$formation_a)
  
  # Remove the temporary columns
  dataframe <- dataframe %>% dplyr::select(-home_team, -away_team)
  
  return(dataframe)
}

position.category <- function(position_name, relevant_formation) {
  # Define a named vector for each position category
  categories <- list(
    Forward = c("Right Center Forward", "Left Center Forward", "Striker", "Secondary Striker", "Center Forward"),
    'Attacking Midfielder' = "Center Attacking Midfield",
    Winger = c("Right Midfield", "Left Midfield", "Left Wing", "Right Wing"),
    'Center Midfielder' = c("Center Midfield", "Left Center Midfield", "Right Center Midfield", "Left Attacking Midfield", "Right Attacking Midfield"),
    'Defensive Midfielder' = c("Center Defensive Midfield", "Left Defensive Midfield", "Right Defensive Midfield"),
    'Full Back' = c("Left Back", "Left Wing Back", "Right Back", "Right Wing Back"),
    'Center Back' = c("Right Center Back", "Left Center Back", "Center Back")
  )
  
  # Check for Goalkeeper or Missing categories
  if (grepl("Goalkeeper", position_name)) {
    return("Goalkeeper")
  } else if (is.na(position_name)) {
    return("Missing")
  }
  
  # Iterate through the categories
  for (category_name in names(categories)) {
    if (position_name %in% categories[[category_name]]) {
      # Special case for Center Back in a Back 3 formation
      if (category_name == "CenterBackBack3" && relevant_formation %in% c(343, 352, 3421)) {
        return("Center Back - Back 3")
      }
      return(category_name)
    }
  }
  
  # Default case if position does not match any category
  return("Missing")
}

shotinfo <- function(dataframe) {
  dataframe <- dataframe %>%
    dplyr::arrange(match_id, index)
  
  # Filter for shots and calculate distance to goal
  shots <- dataframe %>%
    dplyr::filter(type.name == "Shot") %>%
    dplyr::mutate(
      x_diff_goal = 120 - location.x,
      y_diff_goal = 40 - location.y,
      DistToGoal = sqrt(x_diff_goal^2 + y_diff_goal^2)
    ) %>%
    dplyr::select(-x_diff_goal, -y_diff_goal) # Remove the intermediate columns
  
  # Bind the shots data back with the rest of the events
  dataframe <- dplyr::bind_rows(shots, dataframe %>%
                                  dplyr::filter(type.name != "Shot")) %>%
    dplyr::arrange(match_id, index)
  
  return(dataframe)
}

classify_action <- function(data) {
  # Define the boundaries for each pitch area based on the coordinates
  defensive_left_flank <- c(0, 0, 60, 18)
  opposition_left_flank <- c(60, 0, 120, 18)
  defensive_right_flank <- c(0, 62, 60, 80)
  opposition_right_flank <- c(60, 62, 120, 80)
  defensive_box <- c(0, 18, 18, 62)
  opposition_box <- c(102, 18, 120, 62)
  defensive_half_left_half_space <- c(18, 18, 60, 30)
  defensive_half_right_half_space <- c(18, 50, 60, 62)
  attacking_half_left_half_space <- c(60, 18, 102, 30)
  attacking_half_right_half_space <- c(60, 50, 102, 62)
  central_defensive_half <- c(18, 30, 60, 50)
  central_attacking_half <- c(60, 30, 102, 50)
  
  # Function to determine the area of the pitch based on x and y coordinates
  get_area <- function(x, y) {
    if (is.na(x) || is.na(y)) {
      return(NA)
    } else if (x >= defensive_left_flank[1] && x <= defensive_left_flank[3] &&
               y >= defensive_left_flank[2] && y <= defensive_left_flank[4]) {
      return('Defensive Left Flank')
    } else if (x >= opposition_left_flank[1] && x <= opposition_left_flank[3] &&
               y >= opposition_left_flank[2] && y <= opposition_left_flank[4]) {
      return('Opposition Left Flank')
    } else if (x >= defensive_right_flank[1] && x <= defensive_right_flank[3] &&
               y >= defensive_right_flank[2] && y <= defensive_right_flank[4]) {
      return('Defensive Right Flank')
    } else if (x >= opposition_right_flank[1] && x <= opposition_right_flank[3] &&
               y >= opposition_right_flank[2] && y <= opposition_right_flank[4]) {
      return('Opposition Right Flank')
    } else if (x >= defensive_box[1] && x <= defensive_box[3] &&
               y >= defensive_box[2] && y <= defensive_box[4]) {
      return('Defensive Box')
    } else if (x >= opposition_box[1] && x <= opposition_box[3] &&
               y >= opposition_box[2] && y <= opposition_box[4]) {
      return('Opposition Box')
    } else if (x >= defensive_half_left_half_space[1] && x <= defensive_half_left_half_space[3] &&
               y >= defensive_half_left_half_space[2] && y <= defensive_half_left_half_space[4]) {
      return('Defensive Half Left Half Space')
    } else if (x >= defensive_half_right_half_space[1] && x <= defensive_half_right_half_space[3] &&
               y >= defensive_half_right_half_space[2] && y <= defensive_half_right_half_space[4]) {
      return('Defensive Half Right Half Space')
    } else if (x >= attacking_half_left_half_space[1] && x <= attacking_half_left_half_space[3] &&
               y >= attacking_half_left_half_space[2] && y <= attacking_half_left_half_space[4]) {
      return('Attacking Half Left Half Space')
    } else if (x >= attacking_half_right_half_space[1] && x <= attacking_half_right_half_space[3] &&
               y >= attacking_half_right_half_space[2] && y <= attacking_half_right_half_space[4]) {
      return('Attacking Half Right Half Space')
    } else if (x >= central_defensive_half[1] && x <= central_defensive_half[3] &&
               y >= central_defensive_half[2] && y <= central_defensive_half[4]) {
      return('Central Defensive Half')
    } else if (x >= central_attacking_half[1] && x <= central_attacking_half[3] &&
               y >= central_attacking_half[2] && y <= central_attacking_half[4]) {
      return('Central Attacking Half')
    } else {
      return('Other Area')
    }
  }
  
  # Apply the get_area function to each row in the data to classify the action
  data$PitchArea <- mapply(get_area, data$location.x, data$location.y)
  data$EndPitchArea <- mapply(get_area, data$end_location.x, data$end_location.y)
  
  
  return(data)
}

consolidate_end_locations <- function(data_df) {
  # Create end_location.x column
  data_df$end_location.x <- ifelse(
    is.na(data_df$pass.end_location.x), 
    ifelse(is.na(data_df$carry.end_location.x), NA, data_df$carry.end_location.x), 
    data_df$pass.end_location.x
  )
  
  # Create end_location.y column
  data_df$end_location.y <- ifelse(
    is.na(data_df$pass.end_location.y), 
    ifelse(is.na(data_df$carry.end_location.y), NA, data_df$carry.end_location.y), 
    data_df$pass.end_location.y
  )
  
  return
  
  
  return(data_df)
}

calculate_action_length <- function(location.x, location.y, end_location.x, end_location.y) {
  # Calculate the difference in x and y coordinates
  diff_x <- end_location.x - location.x
  diff_y <- end_location.y - location.y
  
  # Calculate the straight-line distance using the Pythagorean theorem
  action_length <- round(sqrt(diff_x^2 + diff_y^2), 0)
  
  return(action_length)
}

# Load the StatsBomb data
Comp <- FreeCompetitions()
Comp <- Comp %>% filter(competition_name == 'FIFA World Cup' & season_id == 106)
Matches <- FreeMatches(Comp)
Match <- Matches %>% filter(match_id == 3869685)
events <- get.matchFree(Match[1,])

# Apply functions
events <- get_and_merge_nicknames(events, Match, get.lineupsFree, cleanlineups)
events <- adjust_timestamps(events)
events <- cleanlocations(events)
events <- formatelapsedtime(events)
events <- possessioninfo(events)
events <- add_opposing_team_column(events)
events <- add_order_column(events)
events <- label_position_categories(events)
events$position.category <- mapply(position.category, events$position.name, events$relevant.formation)
events <- shotinfo(events)
events <- get.gamestate(events); events <- events[[1]]
events <- consolidate_end_locations(events)
events$action_length <- mapply(calculate_action_length, 
                               events$location.x, 
                               events$location.y, 
                               events$end_location.x, 
                               events$end_location.y)

# Select appropriate columns
data <- events %>%
  select(period, minute, timestamp_seconds = adjusted_timestamp_seconds, team.name, opposing.team.name, score = Score, opposing.team.score = OpposingScore, possession_number = possession, possession_team.name,
         event = type.name, event_duration = duration,
         play_pattern.name, player.name, player.position = position.category,
         action_length.yards = action_length, pass.switch, pass.cross, pass.through_ball,
         pass.height = pass.height.name, pass.recipient.name, pass.type.name, pass.body_part.name, pass.outcome.name,
         duel.type.name, duel.outcome.name,
         shot.statsbomb_xg, shot.technique.name, shot.type.name, shot.body_part.name, shot.outcome.name,
         foul_committed.penalty, foul_won.penalty,
         location.x, location.y, end_location.x, end_location.y,
         team.time.in.possession = TimeInPoss,
         game.state = GameState, opposing.team.game.state = OpposingGameState) %>% 
  filter(!is.na(player.name))

#### Change various columns to human readable ####

# Assuming 'data' is your dataframe
data <- data %>%
  mutate(
    # Update period to human-readable form
    period = case_when(
      period == 1 ~ "First Half",
      period == 2 ~ "Second Half",
      period == 3 ~ "First Half Extra Time",
      period == 4 ~ "Second Half Extra Time",
      period == 5 ~ "Penalties",
      TRUE ~ as.character(period)
    ),
    
    # Update score format
    score = ifelse(team.name < opposing.team.name,
                   paste(team.name, score, "-", opposing.team.score, opposing.team.name),
                   paste(opposing.team.name, opposing.team.score, "-", score, team.name)
    ),
    
    # Update game_state format
    game_state = ifelse(team.name < opposing.team.name,
                   paste(team.name, game.state, ",", opposing.team.name, opposing.team.game.state),
                   paste(opposing.team.name, opposing.team.game.state, ",", team.name, game.state)
    ),
    
    # Handle shot events and details
    event_shot = case_when(
      shot.outcome.name == 'Goal' ~ "Goal Scored",
      shot.outcome.name == 'Saved' ~ "Saved Shot",
      shot.outcome.name == 'Blocked' ~ "Blocked Shot",
      shot.outcome.name == 'Off T' ~ "Off Target Shot",
      TRUE ~ NA_character_
    ),
    event_shot = ifelse(!is.na(shot.type.name) & shot.type.name == 'Penalty', paste("Penalty", event_shot), event_shot),
    event_shot = ifelse(!is.na(shot.technique.name) & shot.technique.name == 'Volley', paste(event_shot, "Volley"), event_shot),
    event_shot = ifelse(shot.body_part.name == 'Head', paste(coalesce(event_shot, event), "Headed"), event_shot),
    
    # Handle pass events and details
    event_pass = case_when(
      pass.through_ball == TRUE ~ "Through Ball Pass",
      pass.cross == TRUE ~ "Cross",
      pass.switch == TRUE ~ "Switch Pass",
      pass.height == "High Pass" ~ "Aerial Pass",
      pass.height == "Ground Pass" ~ "Ground Pass",
      TRUE ~ NA_character_
    ),
    
    event_pass = ifelse(pass.outcome.name == 'Out', paste(event_pass, 'Out of Play'), event_pass),
    event_pass = ifelse(pass.outcome.name == 'Incomplete', paste(event_pass, 'Incomplete'), event_pass),
    event_pass = ifelse(pass.outcome.name == 'Pass Offside', paste(event_pass, 'Offside'), event_pass),
    event_pass = ifelse(pass.body_part.name == 'Head', paste(coalesce(event_pass, event), "Headed"), event_pass),
    event_pass = ifelse(!is.na(pass.type.name), pass.type.name, event_pass),
    
    # Handle foul events
    event_foul = case_when(
      foul_committed.penalty == TRUE ~ "Penalty Conceded",
      foul_won.penalty == TRUE ~ "Penalty Won",
      TRUE ~ NA_character_
    ),
    
    # Handle duel events
    event_duel = case_when(
      event == "Duel" & duel.type.name == "Aerial Lost" ~ "Lost Header",
      event == "Duel" & duel.type.name == "Tackle" & duel.outcome.name %in% c("Won", "Success In Play") ~ "Tackle Won",
      event == "Duel" & duel.type.name == "Tackle" & duel.outcome.name %in% c("Lost Out", "Lost In Play") ~ "Tackle Lost",
      TRUE ~ NA_character_
    ),
    
    # Combine all events into a single 'action' column
    action = coalesce(event_shot, event_pass, event_foul, event_duel, event),
    
    # Update chance of scoring percentage
    chance_of_scoring_pcnt = round(shot.statsbomb_xg * 100, 0)
  )

# classify zones of pitch
data <- classify_action(data)
View(data)

# Remove excess events
data_df <- data %>% filter(action != "Ball Receipt*" & action != "Pressure" & action != "Miscontrol" & action != "Goal Keeper" & action != "Dispossessed" & action != "Shield" & action != "50/50")

# Initialize the new column with NA
data_df$timestamp_start_of_possession_seconds <- NA

# Iterate through the rows to fill the new column
for (i in 1:nrow(data_df)) {
  if (i == 1 || data_df$possession_number[i] != data_df$possession_number[i-1]) {
    # Start of a new possession
    data_df$timestamp_start_of_possession_seconds[i] <- data_df$timestamp_seconds[i]
  } else {
    # Continuing the same possession
    data_df$timestamp_start_of_possession_seconds[i] <- data_df$timestamp_start_of_possession_seconds[i-1]
  }
}

# Remove unnecessary columns
data_df <- data_df %>% 
  select(c(period, minute, score, team_in_possession = possession_team.name, possession_number, #, timestamp_seconds, possession_number
           play_pattern_name = play_pattern.name, timestamp_start_of_possession_seconds, #, game_state
           player_name = player.name, player_team_name = team.name, #, player_position = player.position
           action, action_length_yards = action_length.yards, #, action_duration = event_duration
           action_start_pitch_area = PitchArea, action_end_pitch_area = EndPitchArea, 
           pass_recipient_name = pass.recipient.name, chance_of_scoring_pcnt#, team_time_in_possession_seconds = team.time.in.possession
           ))

# Optimize memory footprint
# Remove accents
data_df$player_name <- stri_trans_general(data_df$player_name, "Latin-ASCII")
data_df$pass_recipient_name <- stri_trans_general(data_df$pass_recipient_name, "Latin-ASCII")
data_df <- data_df %>%
  rename_with(~ gsub("\\.", "", .x))

# Convert dataframe to JSON
json_data <- toJSON(data_df, pretty = TRUE)
path <- "/Users/maxodenheimer/Projects/thompson_gpt/scripts/data.json"
write(json_data, path)