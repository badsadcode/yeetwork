shader_type spatial;
// See-through ice (thin ice, small blocks): the view through it is tinted by how much ice
// it crosses. See ice.gdshaderinc.
render_mode blend_mix, cull_back, specular_schlick_ggx;

#define ICE_CLEAR
#include "res://scripts/world/ice.gdshaderinc"
