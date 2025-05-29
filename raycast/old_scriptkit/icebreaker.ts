// Menu: Icebreaker
// Description: Get a random icebreaker question
// Author: Trevor Atlas
// Twitter: @trevoratlas

import '@johnlindquist/kit';

const dbvalues = await db('icebreakers');
const icebreakers: string[] = dbvalues.data;

const getRandomElement = <T>(arr: T[]) => {
  const index = Math.floor(Math.random() * arr.length);
  return arr[index];
};

const item = getRandomElement(icebreakers);

await div(
  `
  <div class="w-full h-full text-center flex items-center justify-center p-16">
    <h1 :class="responseClass">${item}</h1>
  <div>
  `
);
