export enum OpenAIModel {
  DAVINCI_TURBO = "gpt-3.5-turbo"
}

export type WorldCupPossession = {
  timestamp_start_of_possession_seconds: number;
  possession_details: string;
  description: string;
};

