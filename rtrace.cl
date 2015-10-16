// (C) 2015 Nandor Licker. All rights reserved.

constant int WIDTH = 640;
constant int HEIGHT = 480;


constant float3 CAMERA_POS = (float3)(0.0f, 0.0f, -6.0f);
constant float3 CAMERA_Z = (float3)(0.0f, 0.0f,  3.0f);
constant float3 CAMERA_Y = (float3)(0.0f, 1.0f,  0.0f);
constant float3 CAMERA_X = (float3)((float)(640.0f / 480.0f), 0.0f,  0.0f);


/**
 * List of spheres in the scene.
 */
struct Sphere {
  float4 origin;
  float3 colour;
};
constant struct Sphere SPHERES[] = {
  { (float4)( 0.0f, -0.2f, 0.0f, 0.5f), (float3)(1.0f, 0.0f, 0.0f) },
  { (float4)( 0.5f,  0.5f, 0.0f, 0.3f), (float3)(0.0f, 1.0f, 0.0f) },
  { (float4)(-0.5f,  0.5f, 0.0f, 0.1f), (float3)(0.0f, 0.0f, 1.0f) },
};


/**
 * Raytrace function.
 *
 * Computes the colour at a given coordinate.
 */
static float3 raytrace(const float3 rayOrg, const float3 rayDir) {
  for (size_t i = 0; i < sizeof(SPHERES) / sizeof(SPHERES[0]); ++i) {
    constant struct Sphere *sphere = &SPHERES[i];
    float magn = length(cross(rayDir, sphere->origin.xyz - rayOrg));
    if (magn < sphere->origin.w) {
      return sphere->colour;
    }
  }


  return (float3)(0, 0, 0);
}


/**
 * OpenCL kernel wrapper.
 *
 * Computes normalized device coordinates and converts colour to 8 bit RGB.
 */
kernel void raytraceKernel(global write_only uchar *result) {
  // Find out the position of the pixel.
  const int y = get_global_id(0);
  const int x = get_global_id(1);

  // Find the ray origin & direction.
  const float3 pos = (float3)(
      (float)(x - WIDTH / 2) / WIDTH,
      (float)(y - HEIGHT / 2) / HEIGHT,
      1.0f
  );
  const float3 rayOrg = CAMERA_POS;
  const float3 rayDir = normalize(
      pos.x * CAMERA_X +
      pos.y * CAMERA_Y +
      pos.z * CAMERA_Z
  );

  // Start raycasting.
  const float3 colour = raytrace(rayOrg, rayDir);

  // Convert to 8 bit RGB.
  const uchar3 rgb = convert_uchar3_sat_rte(colour * 255.0f);
  const int idx = (y * WIDTH + x) * 3;
  result[idx + 0] = rgb.r;
  result[idx + 1] = rgb.g;
  result[idx + 2] = rgb.b;
}
