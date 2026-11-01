<!-- Made by tools/make_guide.gd from scripts/mapkit/volley_net.gd: change the comments there and run it again, not this page. -->
# VolleyNet

*Modes: a Map Kit piece (Add Child Node > VolleyNet). Script: `scripts/mapkit/volley_net.gd`.* [All the pieces](README.md)

A YeetVolley court: the net across the middle (posts, a solid net the ball and players bounce off) and the court lines on the floor. Put the node on the floor in the middle of the court: the net runs along local X; Red plays on the local -Z side, Blue on +Z. Court: width (X) and length (Z, both halves together). The ball landing inside a half is a point for the other team; landing outside the lines is "out".

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Court** | `(12, 22)` | The court's size, metres: width (X) and length (Z, both halves). |
| **Net Height** | `2.5` | How high the net is, metres. *(1.5 to 5)* |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. A child named "Net" rises with the net (TOTAL YEET). The court lines stay. |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Net` | rises with the net | nothing rises with the net |

## Used in

[Volley Beach](../../maps/volley_beach.tscn)
