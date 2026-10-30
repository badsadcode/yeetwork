shader_type spatial;
// Solid ice (thick ice: floors, big blocks). See ice.gdshaderinc.
render_mode cull_back, specular_schlick_ggx;

#include "res://scripts/world/ice.gdshaderinc"
