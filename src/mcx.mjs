const canvas = document.getElementById("simulationCanvas");
    const context = canvas.getContext("2d");
    const width = 256;
    const height = 256;
    const depth = 64;
    const imageData = context.createImageData(width, height);

    // Device and queue
    const adapter = await navigator.gpu.requestAdapter();
    const device = await adapter.requestDevice();
    const queue = device.queue;

    // Data textures
    const absorption = new Float32Array(width * height * depth).fill(0.1); // Replace with your absorption data
    const scattering = new Float32Array(width * height * depth).fill(0.5); // Replace with your scattering data

    const absorptionTexture = device.createTexture({
      size: { width, height },
      format: "rgba8unorm",
      usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.SAMPLED,
    });

    const scatteringTexture = device.createTexture({
      size: { width, height },
      format: "rgba8unorm",
      usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.SAMPLED,
    });

    // // Upload data to textures
    // queue.writeTexture(absorptionTexture, absorption, { width, height, depth });
    // queue.writeTexture(scatteringTexture, scattering, { width, height, depth });

    const vertexShader = await device.createShaderModule({
      code: `
      struct VertexOutput {
        vec3 position;
      };

      layout(location = 0) in vec3 aPos;

      out VertexOutput vOut;

      void main() {
        vOut.position = aPos;
        gl_Position = vec4(aPos, 1.0);
      }
    `,
    });

    const fragmentShader = await device.createShaderModule({
      code: `
      struct Material {
        float absorption;
        float scattering;
      };

      uniform sampler2D absorptionMap;
      uniform sampler2D scatteringMap;

      layout(location = 0) out vec4 FragColor;
      layout(binding = 0) uniform Material material;

      void main() {
        vec3 worldPos = gl_FragCoord.xyz;
        float absorption = textureSample(absorptionMap, vec2(worldPos.xy / vec2(${width}, ${height}))).r;
        float scattering = textureSample(scatteringMap, vec2(worldPos.xy / vec2(${width}, ${height}))).r;
        // Implement your scattering and absorption calculations here
        FragColor = vec4(0.0); // Replace with calculated fluence
      }
    `,
    });

    // Pipeline creation
    const pipeline = device.createRenderPipeline({
      vertex: {
        module: vertexShader,
        entryPoint: "main",
      },
      fragment: {
        module: fragmentShader,
        entryPoint: "main",
        targets: [
          {
            format: "rgba8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
          },
        ],
      },
      layout: "auto",
    });

    // Command encoder and buffer
    const commandEncoder = device.createCommandEncoder();

    const vertices = new Float32Array([
      // Define your vertex positions for a beam geometry
    ]);

    const vertexBuffer = device.createBuffer({
      size: vertices.byteLength,
      usage: GPUBufferUsage.VERTEX,
      mappedAtCreation: true,
    });

    new Float32Array(vertexBuffer.getMappedRange()).set(vertices);
    vertexBuffer.unmap();

    const textureView = absorptionTexture.createView(); // Replace myTexture with the actual texture object

    // Render pass and texture for storing fluence
    const renderPass = {
      colorAttachments: [
        {
          view: textureView, // Assigned later

          texture: device.createTexture({
            size: { width, height },
            format: "rgba8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
          }),
          loadOp: "clear",
          storeOp: 'store',
          clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
        },
      ],
    };

    const commandBuffer = device.createCommandEncoder();
    const passEncoder = commandEncoder.beginRenderPass(renderPass );

    passEncoder.setPipeline(pipeline);
    passEncoder.setVertexBuffer(0, vertexBuffer);
    passEncoder.setBindGroup(0, {
      bindings: [
        {
          resource: {
            buffer: device.createBuffer({
              size: sizeof(Float32) * 2, // Assuming uniform data is just absorption and scattering
              usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
              mappedAtCreation: true,
            }),
          },
          offset: 0,
          size: sizeof(Float32),
        },
        {
          resource: absorptionTexture,
          offset: sizeof(Float32),
          size: absorptionTexture.size,
        },
        {
          resource: scatteringTexture,
          offset:
            absorptionTexture.size.width * absorptionTexture.size.height * 4 +
            sizeof(Float32),
          size: scatteringTexture.size,
        },
      ],
    });

    const uniformData = new Float32Array(vertexBuffer.getMappedRange());
    uniformData[0] = 0.1;
    uniformData[1] = 0.5;
    vertexBuffer.unmap();

    commandBuffer.copyBufferToBuffer(vertexBuffer, 0, uniformData.byteLength);

    for (let z = 0; z < depth; z++) {
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          // Calculate index in the 1D array representing the 3D texture
          const index = z * width * height + y * width + x;

          // Calculate absorption and scattering values from textures
          const absValue = absorption[index];
          const scaValue = scattering[index];

          // Initialize fluence with initial values from textures
          let fluence = absValue;

          // Perform ray tracing calculations
          for (let i = 0; i < maxSteps; i++) {
            fluence += absValue * (1 - Math.exp(-scaValue * stepSize));

            if (fluence < threshold || isOutOfDomain(x, y, z)) {
              break;
            }

            moveAlongBeamPath();
          }

          fluenceData[index] = fluence;
        }
      }
    }

    for (let i = 0; i < width * height * depth; i++) {
      const fluence = fluenceData[i];
      const grayValue = Math.floor((fluence / maxFluenceValue) * 255);
      imageData.data[i * 4] = grayValue; // Red channel
      imageData.data[i * 4 + 1] = grayValue; // Green channel
      imageData.data[i * 4 + 2] = grayValue; // Blue channel
      imageData.data[i * 4 + 3] = 255; // Alpha channel (fully opaque)
    }

    // Render pass
    commandBuffer.beginRenderPass(renderPass);
    commandBuffer.draw(vertices.length / 3, 1, 0, 0);
    commandBuffer.endRenderPass();

    // Submit command buffer and read fluence data
    commandBuffer.endCommandBuffer();
    queue.submit([commandBuffer]);

    // Read fluence data from render target texture
    const fluenceData = new Float32Array(width * height * depth);
    queue.readTexture(renderPass.attachments[0].texture, fluenceData, {
      width,
      height,
      depth,
    });
    console.log("hi");

    // Process and analyze the fluence data
    context.putImageData(imageData, 0, 0);