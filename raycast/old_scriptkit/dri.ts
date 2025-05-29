// Name: dri
// Group: work

import "@johnlindquist/kit"

import { getWeekNumber } from '../lib/common';

function getMeetingDRI(team: string[]): string {
  const currentDate = new Date();
  const weekNumber = getWeekNumber(currentDate);
  return team[weekNumber % team.length];
}


const FE_TEAM = ['Avery', 'Will', 'Trevor'];
const WHOLE_TEAM = ['Naveen', 'Adam', 'Ray', 'Shilpa', 'Steven', 'Avery', 'Will', 'Trevor', 'Matthew'];

let frontendDRI = getMeetingDRI(FE_TEAM)
let teamDRI = getMeetingDRI(WHOLE_TEAM)

async function update() {
  frontendDRI = getMeetingDRI(FE_TEAM)
  teamDRI = getMeetingDRI(WHOLE_TEAM)
    await notify(`FE DRI is ${frontendDRI}
Team DRI is ${teamDRI}`);
}

setInterval(update, 1000 * 60 * 60 * 12);


const w = await widget(md(`# Meeting DRI Tracker
- The current FE DRI is ${frontendDRI}
- The current team DRI is ${teamDRI}
`));

  w.onClick(async () => {
    update();
  });
