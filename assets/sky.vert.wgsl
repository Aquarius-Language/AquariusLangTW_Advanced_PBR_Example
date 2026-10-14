struct UserUniforms { skyProjection: mat4x4<f32>, };
@group(1) @binding(0) var<uniform> scene: UserUniforms;
struct SkyOutput { @builtin(position) clip:vec4<f32>, @location(0) direction:vec3<f32>, };
@vertex fn vs_main(i:VertexInput)->SkyOutput{
    var o:SkyOutput;o.clip=scene.skyProjection*vec4<f32>(i.position,1.0);
    o.clip.z=o.clip.w;o.direction=i.position;return o;
}
