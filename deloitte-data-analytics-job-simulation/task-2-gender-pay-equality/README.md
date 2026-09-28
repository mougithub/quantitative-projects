# Task 2 — Gender Pay Equality Classification (Excel)

## Background
Following internal complaints about gender pay inequality, Daikibo's Forensic
Tech team built an algorithm that produces an **Equality Score** per job role
and factory: an integer from **-100 to +100**, where 0 is ideal (no gap) and
larger magnitudes indicate a bigger gap in either direction.

## Task
Given `Factory`, `Job Role`, `Equality Score`, classify each row into a 4th
column, **Equality class**:

| Class | Score range |
|---|---|
| Fair | -10 to +10 (inclusive) |
| Unfair | -20 to -11, or +11 to +20 |
| Highly Discriminative | below -20, or above +20 |

## Approach
[`Equality_Table_completed.xlsx`](./Equality_Table_completed.xlsx) adds the
`Equality class` column using a live formula (not hardcoded text), so it
recalculates automatically if the underlying scores ever change:

```
=IF(AND(C2>=-10, C2<=10), "Fair",
   IF(OR(C2<-20, C2>20), "Highly Discriminative", "Unfair"))
```

## Result (summary)
- **Highly Discriminative** roles cluster in senior positions (C-Level, VP,
  Sr. Manager) at Daikibo Factory Meiyo and Daikibo Factory Seiko.
- **Fair** scores are concentrated in engineering/operational roles across
  all 4 factories.
- Daikibo Berlin has the most balanced spread overall, with no roles falling
  into the Highly Discriminative band.

**Recommendation to the client:** focus the compensation review on senior
management and leadership roles at the Meiyo and Seiko factories first, since
that's where the largest and most numerous pay gaps show up.
