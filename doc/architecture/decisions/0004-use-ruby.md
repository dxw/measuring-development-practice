# 4. Use Ruby

Date: 2021-11-26

## Status

Accepted

## Context

We will be writing scripts to implement our ideas, we should choose a language.

## Decision

Use Ruby as our scripting language.

## Consequences

We are using GitHub actions which use JavaScript natively, to use Ruby we will
be adding a layer of complexity to any work as we will also have to use Docker
containers. On balance whilst JS might execute faster, developer happiness is a
factor as well as approachability to this work.
