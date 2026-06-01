enum BarType {
  competition,
  duffalo,
  ssb,
  swiss,
  trap,
  ezCurl,
}

class BarSpec {
  final BarType type;
  final String name;
  final String shortName;
  final double weightLb;
  final String benefit;
  final String bestFor;

  const BarSpec({
    required this.type,
    required this.name,
    required this.shortName,
    required this.weightLb,
    required this.benefit,
    required this.bestFor,
  });
}

const Map<BarType, BarSpec> barSpecs = {
  BarType.competition: BarSpec(
    type: BarType.competition,
    name: 'Competition / Stiff Bar',
    shortName: 'Stiff Bar',
    weightLb: 45,
    benefit: 'Minimal flex, maximum transfer to meet attempts. Standard for all three powerlifting movements.',
    bestFor: 'Squat · Bench · Deadlift',
  ),
  BarType.duffalo: BarSpec(
    type: BarType.duffalo,
    name: 'Duffalo Bar',
    shortName: 'Duffalo',
    weightLb: 55,
    benefit: 'Camber reduces shoulder impingement and lower back shear on squats. Lets you sit into a deeper, more upright position.',
    bestFor: 'Squat · Close-Grip Bench',
  ),
  BarType.ssb: BarSpec(
    type: BarType.ssb,
    name: 'Safety Squat Bar',
    shortName: 'SSB',
    weightLb: 60,
    benefit: 'Forward-loaded handles eliminate shoulder and wrist strain. Hammers upper back and quads harder than a straight bar.',
    bestFor: 'Squat · Good Morning',
  ),
  BarType.swiss: BarSpec(
    type: BarType.swiss,
    name: 'Swiss / Football Bar',
    shortName: 'Swiss Bar',
    weightLb: 35,
    benefit: 'Neutral grip reduces rotator cuff stress. Useful for raw pressers with shoulder issues and for building tricep lockout strength.',
    bestFor: 'Bench Press · Overhead Press · Row',
  ),
  BarType.trap: BarSpec(
    type: BarType.trap,
    name: 'Trap / Hex Bar',
    shortName: 'Trap Bar',
    weightLb: 55,
    benefit: 'Shifts load closer to center of gravity, reducing lower back moment arm. More quad-dominant deadlift pattern.',
    bestFor: 'Deadlift · Shrug · Farmer Carry',
  ),
  BarType.ezCurl: BarSpec(
    type: BarType.ezCurl,
    name: 'EZ Curl Bar',
    shortName: 'EZ Bar',
    weightLb: 25,
    benefit: 'Angled grips reduce wrist and forearm supination stress on curls and skull crushers.',
    bestFor: 'Bicep Curl · Tricep Extension',
  ),
};

BarSpec barSpecFor(BarType t) => barSpecs[t]!;
