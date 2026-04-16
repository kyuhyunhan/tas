# Ethos

Garry Tan's "Thin Harness, Fat Skills" taught us that the bottleneck is
never the model — it's whether the model has the right context at the
right time.

Reading that essay, I was reminded of pure functions in functional
programming. A pure function takes an input, returns an output, and does
nothing else. No hidden state. No side effects. Predictable, composable,
trustworthy.

Skills should work the same way.

The temptation is always to build fat agents full of blackboxes, or
monolithic skills that think on your behalf. But opacity does not produce
solid architecture. Replacing your judgment with a skill's judgment does
not produce a reliable pipeline. It produces something you can no longer
reason about.

TAS exists to resist that temptation.

## Delegate execution, not judgment

Skills handle what computing does best — fast, accurate, repeatable
execution. What to run, when to run it, and how to interpret the results
stays with you.

A skill that grows fat enough to think for you has crossed the line.
That is not delegation. That is abdication.

## Personally useful over widely adopted

A skill that checks every Xcode deployment prerequisite before App Store
submission will never see wide adoption. But if you ship iOS apps, it
saves you from rejection every single time.

Narrow domain, real use. That is the only test.
If you don't use it yourself, it doesn't belong here.
