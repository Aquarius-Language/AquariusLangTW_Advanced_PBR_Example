// Reference asset baker. Copyright (c) 2017-2018 Michał Siejak (renderer/shaders), MIT.
#include <cstdio>
#include <fstream>
#include <vector>
#include <memory>
#include <string>
#include <stdexcept>
#include <algorithm>
#include <glm/glm.hpp>
#include <GLFW/glfw3.h>
#define private public
#include "opengl.hpp"
#undef private
#include "common/mesh.hpp"

static std::string output;
static void dump(const OpenGL::Texture& t,const char* name,int layers,int channels,bool half) {
    std::ofstream file(output+"/"+name,std::ios::binary);
    for(int mip=0;mip<t.levels;mip++) {
        int w=std::max(1,t.width>>mip),h=std::max(1,t.height>>mip);
        std::vector<char> bytes(w*h*layers*channels*(half?2:1));
        glGetTextureImage(t.id,mip,channels==1?GL_RED:GL_RGBA,half?GL_HALF_FLOAT:GL_UNSIGNED_BYTE,(GLsizei)bytes.size(),bytes.data());
        file.write(bytes.data(),bytes.size());
    }
    std::printf("Baked %s: %dx%d, %d mips\n",name,t.width,t.height,t.levels);
}
int main(int argc,char** argv) {
    if(argc!=2)return 2;output=argv[1];
    try {
        if(!glfwInit())throw std::runtime_error("GLFW initialization failed");
        glfwWindowHint(GLFW_VISIBLE,GLFW_FALSE);
        OpenGL::Renderer r;auto window=r.initialize(1024,1024,16);r.setup();glPixelStorei(GL_PACK_ALIGNMENT,1);
        dump(r.m_albedoTexture,"albedo.raw",1,4,false);dump(r.m_normalTexture,"normal.raw",1,4,false);
        dump(r.m_metalnessTexture,"metallic.raw",1,1,false);dump(r.m_roughnessTexture,"roughness.raw",1,1,false);
        dump(r.m_envTexture,"environment.raw",6,4,true);dump(r.m_irmapTexture,"irradiance.raw",6,4,true);dump(r.m_spBRDF_LUT,"brdf.raw",1,4,true);
        auto mesh=Mesh::fromFile("meshes/cerberus.fbx");std::ofstream json(output+"/mesh.json");json.precision(9);json<<"[";bool first=true;
        std::vector<float> tangent;
        for(auto& face:mesh->faces())for(auto index:{face.v1,face.v2,face.v3}) {
            const auto& v=mesh->vertices()[index];if(!first)json<<",";first=false;
            json<<"["<<v.position.x<<","<<v.position.y<<","<<v.position.z<<","<<v.normal.x<<","<<v.normal.y<<","<<v.normal.z<<","<<v.texcoord.x<<","<<v.texcoord.y<<"]";
            tangent.insert(tangent.end(),{v.tangent.x,v.tangent.y,v.tangent.z,0,v.bitangent.x,v.bitangent.y,v.bitangent.z,0});
        }
        json<<"]";json.close();std::ofstream tb(output+"/tangents.f32",std::ios::binary);tb.write((char*)tangent.data(),tangent.size()*sizeof(float));tb.close();
        std::printf("Mesh: %zu vertices, %zu triangles\n",mesh->vertices().size(),mesh->faces().size());
        ViewSettings view{};view.distance=150;view.fov=45;SceneSettings scene{};
        scene.lights[0].direction={-1,0,0};scene.lights[1].direction={1,0,0};scene.lights[2].direction={0,-1,0};
        for(auto& light:scene.lights)light.radiance={1,1,1};
        for(int lit=0;lit<2;lit++) {
            for(auto& light:scene.lights)light.enabled=lit;r.render(window,view,scene);glFinish();
            std::vector<float> pixels(1024*1024*4);glGetTextureImage(r.m_resolveFramebuffer.colorTarget,0,GL_RGBA,GL_FLOAT,(GLsizei)(pixels.size()*4),pixels.data());
            std::ofstream raw(output+(lit?"/reference-lit.f32":"/reference.f32"),std::ios::binary);raw.write((char*)pixels.data(),pixels.size()*4);
        }
        r.shutdown();glfwDestroyWindow(window);glfwTerminate();return 0;
    }catch(std::exception& e){std::fprintf(stderr,"%s\n",e.what());return 1;}
}
