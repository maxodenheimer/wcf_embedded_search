import { NavalJSON, NavalSection, NavalSubsection } from "@/types";
import { loadEnvConfig } from "@next/env";
import { createClient } from "@supabase/supabase-js";
import fs from "fs";
import { Configuration, OpenAIApi } from "openai";

// Ensure your .env file is being read properly
loadEnvConfig(process.cwd());

const generateEmbeddings = async (sections: NavalSection[]) => {
  const configuration = new Configuration({ apiKey: process.env.OPENAI_API_KEY });
  const openai = new OpenAIApi(configuration);

  // Ensure that your Supabase URL and Service Role Key are correctly named and used here
  const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);

  for (const section of sections) {
    // Assuming title, publishedDate, updatedDate are in NavalSection
    const { title, publishedDate, updatedDate, contentHtml, contentText, subsections } = section;

    for (const subsection of subsections) {
      // Assuming subtitle, contentHtml, and contentText are in NavalSubsection
      const { subtitle, contentHtml: subContentHtml, contentText: subContentText } = subsection;

      // Embedding the contentText of the subsection
      const embeddingResponse = await openai.createEmbedding({
        model: "text-embedding-ada-002",
        input: subContentText
      });

      const embedding = embeddingResponse.data.data[0].embedding;

      // Inserting into Supabase, make sure your table columns match these property names
      const { data, error } = await supabase
        .from("naval_posts")
        .insert({
          title,
          subtitle,
          html: subContentHtml,
          content: subContentText,
          published_date: publishedDate, // Make sure to add this column to your Supabase table if it's not already there
          updated_date: updatedDate, // Same as above
          embedding
        })
        .select("*");

      if (error) {
        console.error("Error inserting data:", error);
        break; // Break out of the loop to avoid further errors
      } else {
        console.log("Saved:", title, ">", subtitle);
      }

      // Delay to avoid hitting API rate limits, adjust as necessary
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }
};

(async () => {
  const book: NavalJSON = JSON.parse(fs.readFileSync("scripts/naval.json", "utf8"));
  await generateEmbeddings(book.sections);
})();
