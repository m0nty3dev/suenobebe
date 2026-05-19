// dayKey assignment is handled server-side by the recomputeDayKeys Cloud Function
// (triggered on every morning_wake write). The client uses toDayKey(activeDay)
// and the CF corrects any mismatches. This file is intentionally empty.
