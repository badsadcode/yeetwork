<!-- Made by tools/make_guide.gd from scripts/mapkit/hoop.gd: change the comments there and run it again, not this page. -->
# Hoop

*Modes: a Map Kit piece (Add Child Node > Hoop). Script: `scripts/mapkit/hoop.gd`.* [All the pieces](README.md)

A basketball hoop for YeetHoops: a pole, a backboard to bank shots off, a solid rim and a see-through net, the rim facing local +Z (turn it toward the court). Put the node on the floor at the end of the court. Team: the team that defends it (the other team scores here). A basket counts when the ball drops down through the rim. Shots from beyond the glowing arc on the floor (Three Range from the rim) are worth 3.

It has every [GoalZone](GoalZone.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Three Range** | `8.5` | The three-point line, metres from the basket: a basket from beyond it is worth 3. |

## Used in

[Hoops Court](../../maps/hoops_court.tscn) (2)
