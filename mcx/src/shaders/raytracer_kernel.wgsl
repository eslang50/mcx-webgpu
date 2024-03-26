@group(0) @binding(0) var color_buffer: texture_storage_2d<rgba8unorm, write>;

struct Ray {
    direction: vec3<f32>,
    origin: vec3<f32>,
}

const GRID_SIZE: u32 = 100; // Combined size for all dimensions
const VOXEL_SIZE: f32 = 0.01; // voxel size

var voxelGrid: array<f32> = array<f32>(GRID_SIZE * GRID_SIZE * GRID_SIZE);

fn getVoxelIndex(x: u32, y: u32, z: u32) -> u32 {
  return (z * GRID_SIZE * GRID_SIZE) + (y * GRID_SIZE) + x;
}

for (var z: u32 = 0u; z < GRID_SIZE; z = z + 1u) {
  for (var y: u32 = 0u; y < GRID_SIZE; y = y + 1u) {
    for (var x: u32 = 0u; x < GRID_SIZE; x = x + 1u) {
      let index = getVoxelIndex(x, y, z);
      voxelGrid[index] = 0.0; 
      // later to support refraction/reflection
    }
  }
}

@compute @workgroup_size(8,8,1)
fn main(@builtin(global_invocation_id) GlobalInvocationID : vec3<u32>) {

    let screen_size: vec2<i32> = vec2<i32>(textureDimensions(color_buffer));
    let screen_pos : vec2<i32> = vec2<i32>(i32(GlobalInvocationID.x), i32(GlobalInvocationID.y));

    if (screen_pos.x >= screen_size.x || screen_pos.y >= screen_size.y) {
        return;
    }

    let initialPosition: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0); 
    let initialDirection: vec3<f32> = vec3<f32>(0.0, 0.0, 1.0); 

    // initialize pencil beam

    let pencilBeam: Ray = Ray(
        direction = normalize(initialDirection),
        origin = initialPosition,
    );

    // add loop for hit function to traverse thru voxels
    // detect whether cross voxel boundary based on scattering lens

}

fn march(ray: Ray, max_distance: f32) -> bool {
  var current_position: vec3<f32> = ray.origin;
  var distance_traveled: f32 = 0.0;

  // Loop until reaching max distance or hitting a solid voxel
  while (distance_traveled < max_distance) {
    // Get the index of the voxel at the current position
    let voxel_index: u32 = getVoxelIndex(
      u32(current_position.x / VOXEL_SIZE),
      u32(current_position.y / VOXEL_SIZE),
      u32(current_position.z / VOXEL_SIZE)
    );

    // Access the material value of the current voxel
    let material_value: f32 = voxelGrid[voxel_index];

    // Check if the voxel is solid (material value > threshold)
    if (material_value > 0.5) { 
      return true; // Intersection found 
    }

    // Move to the next voxel along the ray direction
    let step_size: f32 = min(voxel_size, max_distance - distance_traveled);
    current_position += ray.direction * step_size;
    distance_traveled += step_size;
  }
  // No intersection found within the maximum distance
  return false;
}

