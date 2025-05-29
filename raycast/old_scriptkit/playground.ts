// Name: playground

import "@johnlindquist/kit"

const ONE_DAY_IN_MILLISECONDS = 1000 * 60 * 60 * 24;

const haveDaysPassed = ({
  startTime,
  numberOfDays,
}: {
  startTime: number;
  numberOfDays: number;
}) => {
  if (typeof startTime !== 'number') {
    return false;
  }

  const today = Date.now();
  const millisecondsPassed = today - startTime;
  const daysPassed = millisecondsPassed / ONE_DAY_IN_MILLISECONDS;
  return daysPassed >= numberOfDays;
};

await div(`${haveDaysPassed({ startTime: Date.now() - ONE_DAY_IN_MILLISECONDS * 30, numberOfDays: 30 })}`)

