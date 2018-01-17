---
layout: post
title:  "Code review for the government"
date:   2017-01-16 16:48:00
categories: random
---

After we moved to a new address, 3 things needed to happen:

- change my wife’s ID
- change my staying permit
- change the car ID
Since I don’t have much knowledge about government administration, I decided to model the process as software and code-review it to see how efficient it is.

The process is the following:

- When a citizen’s address changes, the new address and a proof of address are required to update his ID.
- When the ID is created, the citizen is notified (I invented this feature to make the process easier to design, the reality resembles more to a sleep/retry loop).
- When a citizen’s address changes, the new address and a proof of address are required to update his resident partner’s staying permit.
- When a citizen’s address changes, the new address and a proof of address are required to update his car registration document.
- When the car registration document is created, the citizen is notified (invented).
- When a resident’s address changes, the new address and a proof of address are required to update his staying permit.
- When staying permit is created, resident is notified about staying permit ready (invented, see above).
I can’t emphasize enough how much I simplified the process. The real version is a bit more complicated.

Next, I will try to model this process as a flow chart.

![government process]({{"/images/government-process.png"}})

I will suppose we are building a software, and a junior developer sent me this initial attempt for code review.

At first glance, it seems that Citizen’s address changed event is requiring 3 actions that are performed at 3 different targets. This is clearly redundant. We can solve this issue in two ways:

Solution 1: Hide all the involved targets behind a single unified interface, something like Citizens affairs Administration. This new administration will be the single contact point with citizens and will handle distributing the event to the interested administration.

Solution 2: Pick one of the existing administrations, the most powerful, the most secure or however you play your politics, and make it act as the unified interface to the citizens.

From software infrastructure point of view, Solution 1 is not the best. It will require new machines to provision, install, develop and run software on. In a governmental institution context, this would mean a whole bunch of construction projects, boring news, and endless nonsense debates on TV. Let’s proceed with Solution 2.

The refactored process :

![government process]({{"/images/government-process-refactored.png"}})

This variation reduces the required actions for a Citizen from 3 to 1. We will suppose we only reduced it from 2 to 1, because not everybody has a car neither everybody has a foreign partner. Although some other people would need other documents to change if they change their addresses, the 2 to 1 average seems a fair compromise. What does that mean in human terms?

I will put a lot of over simplifications on the following estimations:

- Today, there are about 20 million people in Romania.
- On average, a citizen will change his address once in 50 years (read as: on average, a citizen is most likely to never change his address, maybe change it once, but rarely more than once)
- This means in the next 50 years we should expect an average of 400000 address changes/year
- If an optimization reduces 1 hour for each citizen, the population would save 400000 hours/year

That’s 45 years, or the equivalent of a team of 200 people working a full year without taking vacations.
How hard it is, in theory, to shave only 10 hours/year from a citizen’s time spent in administrations in your country?
