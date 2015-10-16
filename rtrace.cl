// (C) 2015 Nandor Licker. All rights reserved.

constant int WIDTH = 1280;
constant int HEIGHT = 768;
constant size_t BOUNCES = 8;


constant float3 CAMERA_POS = (float3)(0.0f, 0.0f, -6.0f);
constant float3 CAMERA_Z = (float3)(0.0f, 0.0f,  3.0f);
constant float3 CAMERA_Y = (float3)(0.0f, 1.0f,  0.0f);
constant float3 CAMERA_X = (float3)((float)(1280.0f / 768.0f), 0.0f,  0.0f);


/**
 * List of spheres in the scene.
 */
struct Sphere {
  float4 origin;
  float3 ambient;
  float3 diffuse;
  float3 specular;
  float3 refl;
};
constant struct Sphere SPHERES[] = {
  {
      (float4)( 0.0f, -0.2f,  0.0f, 0.5f),
      (float3)(1.0f, 0.2f, 0.2f),
      (float3)(1.0f, 0.2f, 0.2f),
      (float3)(1.0f, 0.2f, 0.2f),
      1.0f
  },
  {
      (float4)( 0.7f,  0.7f, -0.2f, 0.4f),
      (float3)(1.0f, 0.2f, 0.2f),
      (float3)(0.2f, 1.0f, 0.2f),
      (float3)(0.2f, 1.0f, 0.2f),
      1.0f
  },
  {
      (float4)(-0.4f,  0.3f,  0.0f, 0.3f),
      (float3)(1.0f, 0.2f, 0.2f),
      (float3)(0.2f, 0.2f, 1.0f),
      (float3)(0.2f, 0.2f, 1.0f),
      1.0f
  },
};


/**
 * List of light sources in the scene.
 */
struct Light {
  float3 ambient;
  float3 diffuse;
  float3 specular;
  float3 direction;
};
constant struct Light LIGHTS[] = {
  {
    (float3)( 0.2f,  0.2f,  0.2f),
    (float3)( 1.0f,  1.0f,  1.0f),
    (float3)( 1.0f,  1.0f,  1.0f),
    (float3)(-1.0f,  1.0f,  1.0f)
  },
  {
    (float3)( 0.2f,  0.2f,  0.2f),
    (float3)( 1.0f,  1.0f,  1.0f),
    (float3)( 0.5f,  0.5f,  0.5f),
    (float3)( 1.0f, -1.0f,  1.0f)
  }
};


/**
 * Intersection point between a ray and any of the spheres.
 */
struct Intersect {
  float3 point;
  float3 normal;
  float3 diffuse;
  float3 refl;
  bool found;
};


/**
 * Computes the reflection of a ray relative to a surface normal.
 */
static float3 reflect(const float3 dir, const float3 normal) {
  return dir - 2.0f * dot(dir, normal) * normal;
}


/**
 * Intersects a ray with any of the spheres.
 */
static struct Intersect intersectSpheres(const float3 rayOrg, const float3 rayDir) {
  struct Intersect intersect = { (float3)0.0f, (float3)0.0f, (float3)0.0f, 0.0f, false };
  float3 diffuse, specular, ambient;
  float minDist = FLT_MAX;

  // Find the object intersected by the ray.
  for (size_t i = 0; i < sizeof(SPHERES) / sizeof(SPHERES[0]); ++i) {
    constant struct Sphere *sphere = &SPHERES[i];

    // Vector to sphere, distance from center, projection of center.
    const float3 toSphere = sphere->origin.xyz - rayOrg;
    const float d = dot(toSphere, rayDir);
    const float3 proj = rayOrg + rayDir * d;
    const float3 v = proj - sphere->origin.xyz;
    const float dist = sqrt(sphere->origin.w * sphere->origin.w - length(v) * length(v));

    // Distance to the intersection point.
    float di = 0.0f;

    // Check if the sphere is inside or outside the origin.
    if (d < 0) {
      // No intersection.
      if (length(toSphere) > sphere->origin.w) {
        continue;
      }

      di = dist - length(proj - rayOrg);
    } else {
      // Find the distance between the sphere and the ray.
      if (length(cross(rayDir, toSphere)) > sphere->origin.w) {
        continue;
      }

      if (length(toSphere) > sphere->origin.w) {
        di = length(proj - rayOrg) - dist;
      } else {
        di = length(proj - rayOrg) + dist;
      }
    }

    if (di < minDist) {
      intersect.point = rayOrg + rayDir * di;
      intersect.normal = normalize(intersect.point - sphere->origin.xyz);
      intersect.refl = 1.0f;//sphere->refl;
      intersect.found = true;

      ambient = sphere->ambient;
      diffuse = sphere->diffuse;
      specular = sphere->specular;

      minDist = di;
    }
  }

  for (size_t i = 0; i < sizeof(LIGHTS) / sizeof(LIGHTS[0]); ++i) {
    constant struct Light *light = &LIGHTS[i];
    const float angle = max(0.0f, dot(intersect.normal, -light->direction));
    const float3 r = reflect(light->direction, intersect.normal);
    const float3 v = normalize(CAMERA_POS - intersect.point);

    // TODO(nandor): find out what's wrong with pow.
    float spec = max(0.0f, dot(r, v));
    spec = spec * spec * spec;

    intersect.diffuse += ambient * light->ambient;
    intersect.diffuse += diffuse * light->diffuse * angle;
    intersect.diffuse += specular * light->specular * spec;
  }

  return intersect;
}


/**
 * Raytrace function.
 *
 * Computes the colour at a given coordinate.
 */
static float3 raytrace(float3 rayOrg, float3 rayDir) {
  float3 diffuse = 0.0f;

  float3 diffuseAcc = 1.0f;
  float3 refl = 1.0f;
  for (size_t i = 0; i < BOUNCES; ++i) {
    struct Intersect intersect = intersectSpheres(rayOrg, rayDir);
    if (!intersect.found) {
      break;
    }

    diffuse += refl * intersect.diffuse * diffuseAcc;
    diffuseAcc *= intersect.diffuse;
    refl *= intersect.refl;
    if (any(refl <= 0.0f)) {
      break;
    }

    rayDir = reflect(rayDir, intersect.normal);
    rayOrg = intersect.point + rayDir * 0.0001f;
  }

  // Compute diffuse illumination.
  return clamp(diffuse, 0.0f, 1.0f);
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
