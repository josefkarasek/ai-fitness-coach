# AI Responsibilities

The AI layer should only receive structured inputs produced by the Go
training engine.

The app client should never be allowed to submit arbitrary prompts
directly to the model provider. Every AI call should come from a
backend-owned workflow with explicit limits, persistence, and audit
data.

## Generate Coaching Book

Inputs: - Athlete profile - Training history summary - Goal - Available
equipment - Constraints

Outputs: - 12-week philosophy - Weekly themes - Exercise selection -
Progression strategy - Expected outcomes - Risks - Success criteria

## Exercise Explanation

For every exercise answer:

Why is this exercise included? How does it contribute to the block? Why
this variation instead of another?

These explanations are generated once and stored.

## Logged Workout Explanation

Inputs:

- Workout structure
- Exercise sequence
- Set and load data
- Workout notes
- Block instructions and notes

Outputs:

- Concise explanation of session intent
- Why the exercise sequence makes sense
- What the loading or rep scheme suggests
- Follow-up coaching observations grounded in the logged data

## Review Completed Block

Inputs:

- Athlete profile
- Planned block
- Completed workout logs
- Weekly summaries
- Key statistics
- Adherence notes

Outputs:

- Block review summary
- What worked
- What did not work
- Risks or recovery concerns
- Recommendations for the next block
