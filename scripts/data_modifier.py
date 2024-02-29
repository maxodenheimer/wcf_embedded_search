import os
import json
import openai

# Assuming the OpenAI library is installed and API key is set in environment variables
client = openai.OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

def generate_description_using_gpt(events):
    """
    Parameters:
    events (list): A list of event data in dictionary format.

    Returns:
    str: A  description of the events.
    """
    # Serialize the list of events to a JSON string for the prompt
    events_json = json.dumps(events, indent=2)
    prompt = f"Given these soccer events: {events_json}, generate a description of the possession. Use the present tense."

    # API call to ChatGPT
    response = client.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are a commentator who describes only the important details. You are pithy and concise."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.1
    )

    description = response.choices[0].message.content
    return(description)

def restructure_json_data(input_file_name, output_file_name):
    """
    Restructures a .json file of soccer events from event grain to possession grain,
    replacing nested actions with a GPT-generated description.
    """
    # Read the original data
    with open(input_file_name, 'r') as file:
        data = json.load(file)

    # Initialize a dictionary to hold the restructured data
    restructured_data = {}

    # Process each event in the data
    for event in data:
        possession_key = (event["timestamp_start_of_possession_seconds"])
        if possession_key not in restructured_data:
            restructured_data[possession_key] = {
                "timestamp_start_of_possession_seconds": event["timestamp_start_of_possession_seconds"],
                "possession_details": f"{event['period']}, {event['score']}, minute {event['minute']}, {event['team_in_possession']} in possession, possession number {event['possession_number']}",
                "events": []  # Collecting events for GPT description
            }

        # Create a dictionary with the details
        event_details = {
            "player_name": event["player_name"],
            "player_team_name": event["player_team_name"],
            "action": event["action"]
        }

        # Check if item exists and append it to event_details if it does
        if "action_length_yards" in event:
            event_details["action_length_yards"] = event["action_length_yards"]
        if "action_start_pitch_area" in event:
            event_details["action_start_pitch_area"] = event["action_start_pitch_area"]
        if "action_end_pitch_area" in event:
            event_details["action_end_pitch_area"] = event["action_end_pitch_area"]
        if "pass_recipient_name" in event:
            event_details["pass_recipient_name"] = event["pass_recipient_name"]


        # Collect event details for GPT description
        restructured_data[possession_key]["events"].append(event_details)

    # Generating descriptions for each possession and restructuring data
    for key, possession in restructured_data.items():
        events = possession.pop("events")  # Remove the events list to replace with description
        description = generate_description_using_gpt(events)  # Generate GPT-based description
        
        # Now, combine the events description with the possession details
        combined_description = f"{possession['possession_details']}\n{description}"
        print(combined_description)
        
        possession["description"] = combined_description  # Add the generated description

    # Convert the restructured data into a list for easier handling
    output_data = [value for key, value in restructured_data.items()]

    # Write the restructured data to a new file
    with open(output_file_name, 'w') as file:
        json.dump(output_data, file, indent=4)

    print(f"Data restructuring complete. New file saved as {output_file_name}")

# Example usage
input_file_name = 'data.json'
output_file_name = 'data_modified.json'
restructure_json_data(input_file_name, output_file_name)
