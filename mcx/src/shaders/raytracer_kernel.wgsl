@group(0) @binding(0) var color_buffer: texture_storage_2d<rgba8unorm, write>;

struct Ray {
    direction: vec3<f32>,
    origin: vec3<f32>,
    elapsedTime: f32,           
    scatteringLengthLeft: f32,   
    energy: f32,                
}

const GRID_SIZE: u32 = 100; // Combined size for all dimensions
const VOXEL_SIZE: f32 = 0.01; // voxel size

var voxelGrid: array<f32> = array<f32>(GRID_SIZE * GRID_SIZE * GRID_SIZE);


var scatteringCoefficients: array<f32> = array<f32>(GRID_SIZE * GRID_SIZE * GRID_SIZE);

fn getVoxelIndex(x: u32, y: u32, z: u32) -> u32 {
  return (z * GRID_SIZE * GRID_SIZE) + (y * GRID_SIZE) + x;
}

fn resetPhoton(vp: Ray) -> Ray {
  return Ray(
    origin: vec3<f32>(0.0, 0.0, 0.0),                      
    direction: vec3<f32>(0.0, 0.0, 0.0),                  
    elapsedTime: 0.0,                                           
    scatteringLengthLeft: -log(random(0.0, 1.0) + 1e-7),      // no random in WGSL
    energy: 1.0,                                               
  );
}

@compute @workgroup_size(8,8,1)
fn main(@builtin(global_invocation_id) GlobalInvocationID : vec3<u32>) {

    let screen_size: vec2<i32> = vec2<i32>(textureDimensions(color_buffer));
    let screen_pos : vec2<i32> = vec2<i32>(i32(GlobalInvocationID.x), i32(GlobalInvocationID.y));

    if (screen_pos.x >= screen_size.x || screen_pos.y >= screen_size.y) {
        return;
    }

    for (var z: u32 = 0u; z < GRID_SIZE; z = z + 1u) {
      for (var y: u32 = 0u; y < GRID_SIZE; y = y + 1u) {
        for (var x: u32 = 0u; x < GRID_SIZE; x = x + 1u) {
          let index = getVoxelIndex(x, y, z);
          voxelGrid[index] = 0.0; 
          scatteringCoefficients[index] = random(0.0, 1.0);
        }
      }
    }

    let initialPosition: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0); 
    let initialDirection: vec3<f32> = vec3<f32>(0.0, 0.0, 1.0); 

    // initialize pencil beam

    var pencilBeam: Ray;
    pencilBeam.direction = normalize(initialDirection);
    pencilBeam.origin = initialPosition;

    let resetPhoton = resetPhoton(myPhoton); 

    let mut currentRay = pencilBeam;


    while (currentRay.scatteringLengthLeft > 0.0) {
        let hit = hit(currentRay, voxelSize, GRID_SIZE, voxelGrid, scatteringCoefficients);
        if (!hit) {
            break;
        }
                
        let scatteringDistance = min(currentRay.scatteringLengthLeft, VOXEL_SIZE);
        currentRay.origin += currentRay.direction * scatteringDistance;
        currentRay.scatteringLengthLeft -= scatteringDistance;

        // Apply scattering effect (adjust energy and direction based on medium properties)
        currentRay.energy *= exp(-scatteringCoefficients[getVoxelIndex(u32(floor(currentRay.origin.x / VOXEL_SIZE)), u32(floor(currentRay.origin.y / VOXEL_SIZE)), u32(floor(currentRay.origin.z / VOXEL_SIZE)))] * scatteringDistance);

    }
    // add loop for hit function to traverse thru voxels
    // detect whether cross voxel boundary based on scattering lens
}

// which face of box is hit by the ray
// hit grid function return dist of closest face
// if dist longer than scattering, take min of 2, that will be distance traveled
// when scattering finished
// if shorter, than move photon to intersection point

fn hit(ray: Ray, voxelSize: f32, gridSize: u32, voxelGrid: array<f32>, scatteringCoefficients: array<f32>) -> bool {
  let mut nearest_t: f32 = f32::MAX;
  let mut intersected: bool = false;
  let mut stepped_position: vec3<f32> = ray.origin;

  // Loop through each dimension (x, y, z)
  for (let dim = 0u; dim < 3u; dim = dim + 1u) {
    let mut t: f32 = (floor(stepped_position[dim] / voxelSize) + 0.5) * voxelSize;
    let step: f32 = if ray.direction[dim] > 0.0 { voxelSize } else { -voxelSize };

    // Check for voxel boundary intersection in this dimension
    while (t >= 0.0 && t <= gridSize as f32 * voxelSize) {
      let i: u32 = getVoxelIndex(u32(floor(t / voxelSize)), u32(floor(stepped_position.y / voxelSize)), u32(floor(stepped_position.z / voxelSize)));

      let scatteringCoefficient: f32 = scatteringCoefficients[i];

      if (voxelGrid[i] > 0.5 && random(0.0, 1.0) < scatteringCoefficient) {
        nearest_t = t;
        intersected = true;
        break; 
      }

      t += step;
    }

    stepped_position[dim] = ray.origin[dim] + nearest_t * ray.direction[dim];
  }

  return intersected;
}

