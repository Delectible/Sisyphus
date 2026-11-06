import 'dart:math' as math;

import 'stats.dart';

/// Short original verses for the summit, picked to suit how the climb went.
enum Mood { first, triumph, steady, long, weary, night, dawn, shortcut }

class Poem {
  final Mood mood;
  final List<String> lines;
  const Poem(this.mood, this.lines);
}

const poems = <Poem>[
  Poem(Mood.first, [
    'The first time up, the hill seemed cruel,',
    'the stone too large, the climb too slow.',
    'Now look: the valley, small as a jewel,',
    'and you, who made it so.',
  ]),
  Poem(Mood.first, [
    'Every legend starts the same:',
    'a person, a weight, a slope, a name.',
    'Yours begins with a single climb.',
    'The rest is only time.',
  ]),
  Poem(Mood.triumph, [
    'The stone is heavy; so am I.',
    'And still we climbed beneath one sky.',
    'It waits to fall. I let it be.',
    'The climbing is what\'s left to me.',
  ]),
  Poem(Mood.triumph, [
    'No god applauds, no crowd, no horn,',
    'just wind across the peak, and quiet.',
    'The stone will roll. The work was worn',
    'like armour. You did not deny it.',
  ]),
  Poem(Mood.triumph, [
    'They meant it as a punishment:',
    'the hill, the stone, the endless rise.',
    'But look how well the hours were spent.',
    'There is a summit in your eyes.',
  ]),
  Poem(Mood.steady, [
    'Push, and rest, and push again:',
    'the oldest rhythm known to men',
    'and mountains. Neither one will tire.',
    'One of them grows a little higher.',
  ]),
  Poem(Mood.steady, [
    'The stone does not care if you are brave.',
    'It only asks that you arrive.',
    'Each step is one the hill once gave',
    'to someone stubborn and alive.',
  ]),
  Poem(Mood.steady, [
    'Up is a direction, not a place.',
    'You keep it facing you like a friend.',
    'The boulder leans its patient face',
    'against your hands. It\'s not the end.',
  ]),
  Poem(Mood.long, [
    'Hours went into the rock today,',
    'pressed like coins into its side.',
    'It will roll down. They\'ll stay.',
    'Some things don\'t slide.',
  ]),
  Poem(Mood.long, [
    'Long climb. The light has changed its mind',
    'three times since you set out.',
    'You left a smaller self behind,',
    'somewhere along the route.',
  ]),
  Poem(Mood.weary, [
    'Some days the hill is twice as tall',
    'and the stone remembers every slight.',
    'You climbed it anyway. That\'s all.',
    'That\'s everything, tonight.',
  ]),
  Poem(Mood.weary, [
    'Rest now. The gods have had their fun.',
    'The stone is lighter than it looks',
    'once it is still and the work is done',
    'and the hill closes like a book.',
  ]),
  Poem(Mood.night, [
    'The stars came out to watch you climb,',
    'old witnesses, and none of them said much.',
    'They\'ve seen a lot of heroes in their time.',
    'They\'ll mention you. They keep in touch.',
  ]),
  Poem(Mood.night, [
    'Late, and the summit wears the moon.',
    'The valley lamps go out below.',
    'The stone will need you again soon.',
    'Not yet. Not yet. Go slow.',
  ]),
  Poem(Mood.dawn, [
    'Before the sun had cleared the ridge',
    'you had already met the stone.',
    'The day is now a smaller bridge',
    'and you have crossed it half alone.',
  ]),
  Poem(Mood.shortcut, [
    'A summit, yes, but by a shortcut.',
    'The boulder raises one stone brow.',
    'It\'s fine. The mountain isn\'t shut.',
    'It will be here. So will you, somehow.',
  ]),
  Poem(Mood.shortcut, [
    'You skipped a little. So did Zeus,',
    'on all his duties, every day.',
    'The stone accepts the small excuse.',
    'Tomorrow, climb the longer way.',
  ]),
];

/// Picks the moods that fit [r], then a poem among them (not [avoid]).
Poem choosePoem(SessionRecord r, {required int mountainsBefore, math.Random? random, Poem? avoid}) {
  final rnd = random ?? math.Random();
  final moods = <Mood>[];
  final hour = r.end.hour;
  if (!r.summited) {
    moods.add(Mood.shortcut);
  } else if (mountainsBefore == 0) {
    moods.add(Mood.first);
  } else {
    if (r.focus >= const Duration(hours: 2)) moods.add(Mood.long);
    if (hour >= 21 || hour < 4) moods.add(Mood.night);
    if (hour >= 4 && hour < 9) moods.add(Mood.dawn);
    if (r.skips > 0 || r.focus >= const Duration(minutes: 150)) moods.add(Mood.weary);
    if (r.skips == 0) moods.add(Mood.triumph);
    moods.add(Mood.steady);
  }
  var pool = poems.where((p) => moods.contains(p.mood) && p != avoid).toList();
  if (pool.isEmpty) pool = poems.where((p) => p.mood == Mood.steady).toList();
  return pool[rnd.nextInt(pool.length)];
}

/// Lines the owl offers in the valley (tap it).
const owlLines = [
  'Hoo. The stone is patient. Be patient too.',
  'Hoo. Rest is part of the climb.',
  'Hoo. Even Atlas puts the sky down sometimes.',
  'Hoo. The mountain is not going anywhere.',
  'Hoo. Drink some water, mortal.',
  'Hoo. The view is better from the bottom than you think.',
  'Hoo. Look at the clouds. They have no deadlines.',
];

/// Cheers for the Motivate button.
const shoveLines = [
  'Onward!',
  'Heave!',
  'For glory!',
  'Up you go!',
  'Not today, gravity.',
  'Keep rolling.',
  'Stone cold focus.',
  'Hup!',
  'One more step.',
  'Almost there.',
];
