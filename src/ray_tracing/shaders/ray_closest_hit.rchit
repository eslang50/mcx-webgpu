layout(set = 1, binding = 1) uniform sampler2D absorptionMap;
layout(set = 1, binding = 2) uniform sampler2D scatteringMap;

void main() {
    float absorptionProb = textureSample(absorptionMap, gl_InstanceIndex.xy).r;
    float scatteringProb = textureSample(scatteringMap, gl_InstanceIndex.xy).r;

    if (random() < absorptionProb) {
        TerminateRay();
    } else if (random() < absorptionProb + scatteringProb) {
        // Ray is scattered, generate a new scattered ray
        TraceRay(hitPoint, scatteredRayDirection, maxDistance);
    } else {
        // Ray continues along its original direction
    }
}