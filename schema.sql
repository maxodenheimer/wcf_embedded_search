--  RUN 1st
create extension vector;

-- RUN 2nd
CREATE TABLE worldcup_possessions (
  id BIGSERIAL PRIMARY KEY,
  timestamp_start_of_possession_seconds NUMERIC,
  possession_details TEXT,
  description TEXT,
  embedding vector (1536)
);

-- RUN 3rd after running the scripts
CREATE OR REPLACE FUNCTION worldcup_possessions_search (
  query_embedding VECTOR(1536),
  similarity_threshold FLOAT,
  match_count INT
)
RETURNS TABLE (
  id BIGINT,
  timestamp_start_of_possession_seconds NUMERIC,
  possession_details TEXT,
  description TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    worldcup_possessions.id,
    worldcup_possessions.timestamp_start_of_possession_seconds,
    worldcup_possessions.possession_details,
    worldcup_possessions.description,
    1 - (worldcup_possessions.embedding <=> query_embedding) AS similarity
  FROM worldcup_possessions
  WHERE 1 - (worldcup_possessions.embedding <=> query_embedding) > similarity_threshold
  ORDER BY worldcup_possessions.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;


-- RUN 4th
create index on worldcup_possessions
using ivfflat (embedding vector_cosine_ops)
with (lists = 100);