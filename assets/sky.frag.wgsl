@group(2) @binding(0) var environmentMap:texture_cube<f32>;
@group(2) @binding(8) var environmentSampler:sampler;
struct SkyOutput { @builtin(position) clip:vec4<f32>, @location(0) direction:vec3<f32>, };
@fragment fn fs_main(i:SkyOutput)->@location(0) vec4<f32>{return vec4<f32>(textureSampleLevel(environmentMap,environmentSampler,normalize(i.direction),0.0).rgb,1.0);}
