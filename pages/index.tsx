import { Footer } from "@/components/Footer";
import { Navbar } from "@/components/Navbar";
import { Player } from "@/components/Player";
import { IconArrowRight, IconSearch } from "@tabler/icons-react";
import Head from "next/head";
import { KeyboardEvent, useEffect, useRef, useState } from "react";

export default function Home() {
  const inputRef = useRef<HTMLInputElement>(null);

  const [query, setQuery] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);

  const [showSettings, setShowSettings] = useState<boolean>(false);
  const [matchCount, setMatchCount] = useState<number>(3);
  const [apiKey, setApiKey] = useState<string>("");

  const [time, setTime] = useState<number>(0);

  const handleSearch = async () => {
    if (!apiKey) {
      alert("Please enter an API key.");
      return;
    }

    if (!query) {
      alert("Please enter a query.");
      return;
    }

    setLoading(true);

    try {
      const searchResponse = await fetch("/api/search", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ query, apiKey, matches: matchCount })
      });

      if (!searchResponse.ok) {
        throw new Error(`Error: ${searchResponse.status} ${searchResponse.statusText}`);
      }

      const results = await searchResponse.json();
      if (!results.possessions || results.possessions.length === 0) {
        throw new Error("No data found for the given query.");
      }

      const possession = results.possessions[0];
      setTime(possession.timestamp_start_of_possession_seconds);
    } catch (error) {
      console.error("Search failed:", error);
      alert(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") {
      handleSearch();
    }
  };

  const handleSave = () => {
    if (apiKey.length !== 51) {
      alert("Please enter a valid API key.");
      return;
    }

    localStorage.setItem("PG_KEY", apiKey);
    localStorage.setItem("PG_MATCH_COUNT", matchCount.toString());
  };

  const handleClear = () => {
    localStorage.removeItem("PG_KEY");
    localStorage.removeItem("PG_MATCH_COUNT");

    setApiKey("");
    setMatchCount(3);
  };

  useEffect(() => {
    const PG_KEY = localStorage.getItem("PG_KEY");
    const PG_MATCH_COUNT = localStorage.getItem("PG_MATCH_COUNT");

    if (PG_KEY) {
      setApiKey(PG_KEY);
    }

    if (PG_MATCH_COUNT) {
      setMatchCount(parseInt(PG_MATCH_COUNT));
    }
  }, []);

  return (
    <>
      <Head>
        <title>Carlo GPT</title>
        <meta name="description" content="AI-powered search & chat for the World Cup Final." />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <div className="flex flex-col h-screen">
        <Navbar />
        <div className="flex-1 overflow-auto">
          <div className="mx-auto flex h-full w-full max-w-[750px] flex-col items-center px-3 pt-4 sm:pt-8">
            {/* Settings Toggle Button and Input Fields */}
            <button
              className="mt-4 flex cursor-pointer items-center space-x-2 rounded-full border border-zinc-600 px-3 py-1 text-sm hover:opacity-50"
              onClick={() => setShowSettings(!showSettings)}
            >
              {showSettings ? "Hide" : "Show"} Settings
            </button>

            {showSettings && (
              <div className="w-[340px] sm:w-[400px]">
                {/* API Key Input */}
                <div className="mt-2">
                  <input
                    type="password"
                    placeholder="OpenAI API Key"
                    className="max-w-[400px] block w-full rounded-md border border-gray-300 p-2 text-black shadow-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 sm:text-sm"
                    value={apiKey}
                    onChange={(e) => setApiKey(e.target.value)}
                  />
                </div>

                {/* Save and Clear Buttons */}
                <div className="mt-4 flex space-x-2 justify-center">
                  <div
                    className="flex cursor-pointer items-center space-x-2 rounded-full bg-green-500 px-3 py-1 text-sm text-white hover:bg-green-600"
                    onClick={handleSave}
                  >
                    Save
                  </div>
                  <div
                    className="flex cursor-pointer items-center space-x-2 rounded-full bg-red-500 px-3 py-1 text-sm text-white hover:bg-red-600"
                    onClick={handleClear}
                  >
                    Clear
                  </div>
                </div>
              </div>
            )}

            {/* Search Input and Button */}
            {apiKey.length === 51 && (
              <div className="relative w-full mt-4">
                <IconSearch className="absolute top-3 w-10 left-1 h-6 rounded-full opacity-50 sm:left-3 sm:top-4 sm:h-8" />
                <input
                  ref={inputRef}
                  className="h-12 w-full rounded-full border border-zinc-600 pr-12 pl-11 focus:border-zinc-800 focus:outline-none focus:ring-1 focus:ring-zinc-800 sm:h-16 sm:py-2 sm:pr-16 sm:pl-16 sm:text-lg"
                  type="text"
                  placeholder="Show me the kick off"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  onKeyDown={handleKeyDown}
                />
                <button>
                  <IconArrowRight
                    onClick={handleSearch}
                    className="absolute right-2 top-2.5 h-7 w-7 rounded-full bg-blue-500 p-1 hover:cursor-pointer hover:bg-blue-600 sm:right-3 sm:top-3 sm:h-10 sm:w-10 text-white"
                  />
                </button>
              </div>
            )}

            {loading && (
              <div className="mt-6 w-full animate-pulse">
                <div className="h-4 bg-gray-300 rounded"></div>
                <div className="h-4 bg-gray-300 rounded mt-2"></div>
                <div className="h-4 bg-gray-300 rounded mt-2"></div>
              </div>
            )}

            {/* Player Component */}
            {!loading && time > 0 && (
              <div className="mt-6 mb-16">
                <div className="font-bold text-2xl mb-2">Player</div>
                <Player
                  src="https://hyfhswowpgukcyawdumw.supabase.co/storage/v1/object/sign/my-video/my-video.mp4?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1cmwiOiJteS12aWRlby9teS12aWRlby5tcDQiLCJpYXQiOjE3MDA5ODM0MDUsImV4cCI6MTczMjUxOTQwNX0.K7GWqnBgtdgE8GQDqtx4bZUzUezIUwtXVfJtq16zXhI&t=2023-11-26T07%3A23%3A25.234Z"
                  startTime={time}
                />
              </div>
            )}
          </div>
        </div>
        <Footer />
      </div>
    </>
  );
}
