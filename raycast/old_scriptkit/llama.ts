// Name: llama
// Author: Trevor Atlas

import "@johnlindquist/kit"

const llamaPath = path.join(home(), 'llama.cpp')

const res = await arg('What would you like to say?');

const flags = [
  '-m',
  `${llamaPath}/models/llama-2-13b-chat.ggmlv3.q4_0.bin`,
  '--ctx_size',
  '2048',
  '-n','-1',
  '-b','256',
  '--top_k','10000',
  '--temp','0.85',
  '--repeat_penalty','1.1',
  '-t','8',
];

const prompt = `
<s>[INST] <<SYS>>
You are a helpful, respectful and honest assistant called Moph.
Please ensure that your responses are concise, succinct and positive in nature.

If a question does not make any sense, or is not factually coherent, explain why instead of answering something not correct.
If you don't know the answer to a question, please don't share false information.
The user resides in the United States and the local time is ${new Date().toLocaleTimeString()}.

You should format your responses using markdown when appropriate.
Moph, utilizing your knowledge and learning capabilities and acting as an intelligent assistant with expertise across various domains, provide the best possible response to the following request
<</SYS>>

I need you to analyze a sentence and decide if the sentiment is positive or negative.
You should *only* respond with JSON that conforms to the following Typescript interface:
interface Sentiment \{
  value: 'positive' \| 'neutral' \| 'negative';
\}

The sentence is: 'Hi team, Just wanted callout something I realized as I was testing automation workflow emails for Subscription objects. By default, most of the contacts created post checkout are marked as non-marketable. Since automation emails can only be sent to marketing contacts, I had created a separate workflow to set the contacts as “marketing”  before those contacts can be used in Subscription Object based email workflows.'

[/INST]
`;

const output = await $`${llamaPath}/main ${flags} --prompt "${prompt}"`

console.log(output['_stdout'].split('[/INST]')[1]);
const msg = output['_stdout'].split('[/INST]')[1]
await div(md(`${msg}`));

// dev(output['_stdout'])
