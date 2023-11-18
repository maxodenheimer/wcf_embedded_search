import { NavalJSON, NavalSection, NavalSubsection } from "@/types";
import axios from "axios";
import * as cheerio from "cheerio";
import fs from "fs";
import { encode } from "gpt-3-encoder";

const scrapePost = async () => {
  const html = await axios.get("https://stratechery.com");
  const $ = cheerio.load(html.data);
  const content = $(".post"); // Update this selector to match the article container on the webpage

  let sections: NavalSection[] = [];

  content.each((_, el) => {
    // Assuming each '.post' is an article
    const article = $(el);
    const title = article.find(".entry-title").text();
    const publishedDate = article.find(".entry-date.published").attr("datetime");
    const updatedDate = article.find(".updated").attr("datetime");
    const contentHtml = article.find(".entry-content").html();
    const contentText = article.find(".entry-content").text();

    let subsections: NavalSubsection[] = [];
    article.find("h3").each((_, subEl) => {
      const subtitle = $(subEl).text();
      let subsectionContentHtml = "";
      let subsectionContentText = "";

      $(subEl).nextUntil("h3").each((_, contentEl) => {
        subsectionContentHtml += $.html(contentEl);
        subsectionContentText += $(contentEl).text();
      });

      subsections.push({
        subtitle: subtitle,
        contentHtml: subsectionContentHtml,
        contentText: subsectionContentText,
      });
    });

    sections.push({
      title: title,
      publishedDate: publishedDate || "",
      updatedDate: updatedDate || "",
      contentHtml: contentHtml || "",
      contentText: contentText,
      subsections: subsections,
    });
  });

  return sections;
};

(async () => {
  const sections = await scrapePost();

  const json: NavalJSON = {
    url: "https://stratechery.com",
    sections: sections,
  };

  console.log(`Sections: ${sections.length}`);

  fs.writeFileSync("scripts/naval.json", JSON.stringify(json, null, 2)); // The null, 2 arguments format the JSON for readability
})();
