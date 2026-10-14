// WGSL port of Nadrin/PBR. Copyright (c) 2017-2018 Michał Siejak, MIT.
struct UserUniforms {
    viewProjection: mat4x4<f32>, sceneRotation: mat4x4<f32>, eye: vec4<f32>,
    light0: vec4<f32>, light1: vec4<f32>, light2: vec4<f32>,
};
@group(1) @binding(0) var<uniform> scene: UserUniforms;
@group(2) @binding(7) var tangentData: texture_2d<f32>;
struct PbrOutput {
    @builtin(position) clip: vec4<f32>, @location(0) world: vec3<f32>,
    @location(1) uv: vec2<f32>, @location(2) normal: vec3<f32>,
    @location(3) tangent: vec3<f32>, @location(4) bitangent: vec3<f32>,
};
@vertex fn vs_main(input: VertexInput, @builtin(vertex_index) index: u32) -> PbrOutput {
    var o: PbrOutput;
    let t = index * 2u;
    let tangent = textureLoad(tangentData,vec2<i32>(i32(t%1024u),i32(t/1024u)),0).xyz;
    let bitangent = textureLoad(tangentData,vec2<i32>(i32((t+1u)%1024u),i32((t+1u)/1024u)),0).xyz;
    let world = scene.sceneRotation * vec4<f32>(input.position,1.0);
    var clip = scene.viewProjection * world; clip.z = (clip.z+clip.w)*0.5;
    o.clip=clip; o.world=world.xyz; o.uv=vec2<f32>(input.texcoord.x,1.0-input.texcoord.y);
    o.normal=(scene.sceneRotation*vec4<f32>(input.normal,0.0)).xyz;
    o.tangent=(scene.sceneRotation*vec4<f32>(tangent,0.0)).xyz;
    o.bitangent=(scene.sceneRotation*vec4<f32>(bitangent,0.0)).xyz;
    return o;
}
