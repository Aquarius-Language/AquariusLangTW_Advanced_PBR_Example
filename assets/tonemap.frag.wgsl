// Reference's exposure=1, pureWhite=1 and gamma=2.2.
@fragment fn fs_main(i:VertexOutput)->@location(0) vec4<f32>{
    let color=max(textureSample(surface,surfaceSampler,i.uv).rgb,vec3<f32>(0.0));
    let luminance=dot(color,vec3<f32>(0.2126,0.7152,0.0722));
    let mapped=luminance*(1.0+luminance)/(1.0+luminance);
    let scale=select(0.0,mapped/max(luminance,1e-12),luminance>0.0);
    return vec4<f32>(pow(color*scale,vec3<f32>(1.0/2.2)),1.0);
}
