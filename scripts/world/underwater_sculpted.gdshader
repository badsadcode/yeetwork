shader_type spatial;
// Underwater pass for "sculpted" water (see underwater.gdshader).
// Full-screen pass drawn by the local camera near a liquid. Every pixel checks whether
// its point on the near plane is under the (waving) surface, so with your eyes at the
// waterline the screen splits: above stays clear, below gets underwater fog and light
// shafts, with a wobbly meniscus line where the surface cuts the lens.
// Fog only covers the water the view ray crosses: looking up, it stops at the surface, so
// the surface shader's Snell's window (the world above) stays visible.
render_mode unshaded, blend_premul_alpha, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scripts/world/liquid_waves_sculpted.gdshaderinc"
#include "res://scripts/world/underwater_pass.gdshaderinc"
