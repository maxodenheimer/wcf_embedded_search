import { loadEnvConfig } from "@next/env";
import { createClient } from "@supabase/supabase-js";
import fs from "fs";
import path from "path";
import { Configuration, OpenAIApi } from "openai";

// Load environment configuration
loadEnvConfig(process.cwd());

// Helper function for delaying execution
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Function to handle retries for fetch operations
async function fetchWithRetry(fetchFunction) {
  const MAX_RETRIES = 3;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      return await fetchFunction();
    } catch (error) {
      if (error.response && error.response.status === 503 && attempt < MAX_RETRIES) {
        console.log(`Attempt ${attempt} failed with 503, retrying after delay...`);
        await delay(2000); // Using a 2-second delay for retry after failure
      } else {
        throw error;
      }
    }
  }
  throw new Error('Max retries reached for OpenAI API request');
}

// Main function to generate embeddings and save them to Supabase
const generateEmbeddings = async (items) => {
  const configuration = new Configuration({ apiKey: process.env.OPENAI_API_KEY });
  const openai = new OpenAIApi(configuration);

  // Initialize Supabase client
  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

  for (let i = 0; i < items.length; i++) {
    const { timestamp_start_of_possession_seconds, possession_details, description } = items[i];

    try {
      // Fetch embeddings with retries
      const embeddingResponse = await fetchWithRetry(() =>
        openai.createEmbedding({
          model: "text-embedding-3-small",
          input: description
        })
      );

      const [{ embedding }] = embeddingResponse.data.data;

      // Insert data into Supabase under the new table name "worldcup_possessions"
      const { data, error } = await supabase
        .from("worldcup_possessions")
        .insert({
          timestamp_start_of_possession_seconds,
          possession_details,
          description,
          embedding
        });

      if (error) {
        console.log("Error saving to Supabase:", error.message);
      } else {
        console.log("Saved item:", i);
      }
    } catch (error) {
      console.error("Error during processing item:", i, error.message);
    }

    // Delay between processing of each item
    await delay(1000);
  }
};

// Execute the script
(async () => {
  // Correctly specify the path to the data_modified.json file
  const filePath = path.join(process.cwd(), "scripts", "data_modified.json");

  // Read and parse the JSON file
  const items = JSON.parse(fs.readFileSync(filePath, "utf8"));
  await generateEmbeddings(items);
})();
