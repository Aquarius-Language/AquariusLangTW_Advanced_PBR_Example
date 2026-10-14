// Lambert + Cook-Torrance + split-sum IBL, ported from Nadrin/PBR.
// Copyright (c) 2017-2018 Michał Siejak, MIT. See PBR-LICENSE.txt.
struct UserUniforms {
    viewProjection: mat4x4<f32>, sceneRotation: mat4x4<f32>, eye: vec4<f32>,
    light0: vec4<f32>, light1: vec4<f32>, light2: vec4<f32>,
};
@group(1) @binding(0) var<uniform> scene: UserUniforms;
@group(2) @binding(0) var albedoMap: texture_2d<f32>;
@group(2) @binding(1) var normalMap: texture_2d<f32>;
@group(2) @binding(2) var metallicMap: texture_2d<f32>;
@group(2) @binding(3) var roughnessMap: texture_2d<f32>;
@group(2) @binding(4) var environmentMap: texture_cube<f32>;
@group(2) @binding(5) var irradianceMap: texture_cube<f32>;
@group(2) @binding(6) var brdfMap: texture_2d<f32>;
@group(2) @binding(8) var materialSampler: sampler;
struct PbrOutput {
    @builtin(position) clip: vec4<f32>, @location(0) world: vec3<f32>,
    @location(1) uv: vec2<f32>, @location(2) normal: vec3<f32>,
    @location(3) tangent: vec3<f32>, @location(4) bitangent: vec3<f32>,
};
fn fresnel(f0:vec3<f32>,cosTheta:f32)->vec3<f32>{return f0+(vec3<f32>(1.0)-f0)*pow(1.0-cosTheta,5.0);}
fn ggx(nh:f32,roughness:f32)->f32{let alpha=roughness*roughness;let a2=alpha*alpha;let d=nh*nh*(a2-1.0)+1.0;return a2/max(3.141592*d*d,1e-12);}
fn geometry(nl:f32,nv:f32,roughness:f32)->f32{let r=roughness+1.0;let k=r*r/8.0;return nl/(nl*(1.0-k)+k)*nv/(nv*(1.0-k)+k);}
@fragment fn fs_main(i:PbrOutput,@builtin(front_facing) front:bool)->@location(0) vec4<f32>{
    let albedo=textureSample(albedoMap,materialSampler,i.uv).rgb;
    let metal=textureSample(metallicMap,materialSampler,i.uv).r;
    let roughness=textureSample(roughnessMap,materialSampler,i.uv).r;
    let mapped=normalize(2.0*textureSample(normalMap,materialSampler,i.uv).rgb-1.0);
    let n=normalize(mat3x3<f32>(i.tangent,i.bitangent,i.normal)*mapped);
    let v=normalize(scene.eye.xyz-i.world);let nv=max(0.0,dot(n,v));let reflection=2.0*nv*n-v;
    let f0=mix(vec3<f32>(0.04),albedo,metal);
    var direct=vec3<f32>(0.0);
    var directions=array<vec3<f32>,3>(vec3<f32>(1.0,0.0,0.0),vec3<f32>(-1.0,0.0,0.0),vec3<f32>(0.0,1.0,0.0));
    var colors=array<vec3<f32>,3>(scene.light0.rgb,scene.light1.rgb,scene.light2.rgb);
    for(var j=0u;j<3u;j++){
        let l=directions[j];let h=normalize(l+v);let nl=max(0.0,dot(n,l));let nh=max(0.0,dot(n,h));
        let f=fresnel(f0,max(0.0,dot(h,v)));let d=ggx(nh,roughness);let g=geometry(nl,nv,roughness);
        let kd=(vec3<f32>(1.0)-f)*(1.0-metal);
        direct+=(kd*albedo+(f*d*g)/max(0.00001,4.0*nl*nv))*colors[j]*nl;
    }
    let irradiance=textureSample(irradianceMap,materialSampler,n).rgb;
    let f=fresnel(f0,nv);let kd=(vec3<f32>(1.0)-f)*(1.0-metal);
    let specular=textureSampleLevel(environmentMap,materialSampler,reflection,roughness*f32(textureNumLevels(environmentMap))).rgb;
    let brdf=textureSample(brdfMap,materialSampler,vec2<f32>(nv,roughness)).rg;
    if(!front){discard;}
    return vec4<f32>(direct+kd*albedo*irradiance+(f0*brdf.x+brdf.y)*specular,1.0);
}
