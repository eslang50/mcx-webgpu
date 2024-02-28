import * as WebGPU from 'webgpu';

const canvas = document.getElementById("simulationCanvas");

const gridDimensions = [32, 32, 16];

const voxelData = new Float32Array(gridDimensions[0] * gridDimensions[1] * gridDimensions[2]);

for (let i = 0; i < voxelData.length; i++) {
  voxelData[i] = 0.0; 
}