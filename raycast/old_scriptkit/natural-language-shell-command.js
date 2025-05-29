// Name: Natural Language Shell Command
// Description: Convert a natural language command to a shell command
// Author: Laura Okamoto
// Twitter: @laura_okamoto

import "@johnlindquist/kit";

const OpenAI = await npm("openai");

const apiKey = await env("OPENAI_API_KEY");
const client = new OpenAI({ apiKey });

const res = await arg("Describe the shell command you want to run");
const completion = await client.chat.completions.create({
  messages: [{role: 'user', content: `DO NOT EXPLAIN! Use the following shell command to "${res}":`}],
  model: "gpt-4",
});

dev(completion)
await paste(completion.choices[0]?.message?.content?.trim());

