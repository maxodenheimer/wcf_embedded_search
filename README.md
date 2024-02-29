# Carlo GPT

AI-powered search for a soccer match.


Everything is 100% open source.

## Dataset

The dataset is brought in via Statsbomb's free event data dataset.

## How It Works

Carlo GPT provides 2 things:

1. Search
2. Video

### Search

Search was created with [OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings) (`text-embedding-ada-002`).

First, we format soccer events into possessions.

Then we use gpt 3.5 turbo to generate descriptions of the possessions and generate embeddings for each chunk of text.

In the app, we take the user's search query, generate an embedding, and use the result to find the most similar passage of play.

The comparison is done using cosine similarity across our database of vectors.

Our database is a Postgres database with the [pgvector](https://github.com/pgvector/pgvector) extension hosted on [Supabase](https://supabase.com/).

Results are ranked by similarity score and returned to the user.

### Video

Video builds on top of search. It uses search results to jump to the relevant timestamp in the video.
