// Name: Units Convert
// Description: Convert between metric and imperial units
// Author: Vedinsoh
// GitHub:

import "@johnlindquist/kit";
const convert = await npm("convert-units");

const getAllPossibilities = (unit) => {
  const possibilities = unit
    ? convert().from(unit).possibilities()
    : convert().possibilities();

  return possibilities
    .map((u) => {
      const uDetails = convert().describe(u);
      return {
        name: `${u} - ${uDetails.plural}`,
        value: u,
      };
    })
    .sort((a, b) => {
      const aDetails = convert().describe(a.value);
      const bDetails = convert().describe(b.value);
      if (aDetails.system === bDetails.system) {
        return aDetails.value - bDetails.value;
      }
      return aDetails.system - bDetails.system;
    });
};

const getUnitString = (unit) => {
  const unitDetails = convert().describe(unit);
  return `${unitDetails.plural} (${unit})`;
};

const convertUnits = (from, to, amount) => {
  return String(convert(amount).from(from).to(to));
};

const fromUnit = await arg({
  placeholder: "From",
  choices: getAllPossibilities(),
  enter: "To",
});

const toUnit = await arg({
  placeholder: "To",
  choices: getAllPossibilities(fromUnit),
  enter: "Amount",
  hint: `Convert from ${fromUnit} to...`,
});

await arg({
  placeholder: "Amount",
  type: "number",
  enter: "Exit",
  hint: `${getUnitString(fromUnit)} equals...`,
  onInput: (input) => {
    const result = convertUnits(fromUnit, toUnit, input);
    setPanel(md(`# ${result} ${getUnitString(toUnit)}`));
  },
  shortcuts: [
    {
      name: "Copy result",
      key: `${cmd}+c`,
      onPress: (input) => {
        copy(convertUnits(fromUnit, toUnit, input));
      },
      bar: "right",
    },
  ],
});
