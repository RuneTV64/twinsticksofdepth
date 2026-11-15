const fs=require('fs');
function readGLB(file){const b=fs.readFileSync(file);if(b.readUInt32LE(0)!==0x46546C67||b.readUInt32LE(4)!==2||b.readUInt32LE(8)!==b.length)throw new Error('bad header');
  const jl=b.readUInt32LE(12);if(b.readUInt32LE(16)!==0x4E4F534A)throw new Error('no json');const json=JSON.parse(b.slice(20,20+jl).toString());
  const bo=20+jl,bl=b.readUInt32LE(bo);if(b.readUInt32LE(bo+4)!==0x004E4942||bl!==json.buffers[0].byteLength)throw new Error('bad bin');const bin=b.slice(bo+8,bo+8+bl);
  const get=i=>{const a=json.accessors[i],v=json.bufferViews[a.bufferView],n={VEC4:4,VEC3:3,VEC2:2,SCALAR:1,MAT4:16}[a.type],T={5126:Float32Array,5121:Uint8Array,5123:Uint16Array,5125:Uint32Array}[a.componentType];
    if(v.byteOffset+a.count*n*T.BYTES_PER_ELEMENT>bin.length||v.byteOffset%4)throw new Error('accessor '+i+' out of range');
    return new T(bin.buffer.slice(bin.byteOffset+v.byteOffset,bin.byteOffset+v.byteOffset+a.count*n*T.BYTES_PER_ELEMENT));};
  return{json,get};}
function check(file){const {json,get}=readGLB(file),pr=json.meshes[0].primitives[0],A=pr.attributes,P=get(A.POSITION),N=get(A.NORMAL),J=get(A.JOINTS_0),W=get(A.WEIGHTS_0),I=get(pr.indices),UV=get(A.TEXCOORD_0),UV2=get(A.TEXCOORD_1),C=get(A.COLOR_0),nv=P.length/3,sk=json.skins[0],NB=sk.joints.length,ibm=get(sk.inverseBindMatrices);
  let mi=0;for(const v of I)if(v>mi)mi=v;let ws=0,jb=0,nl=0;for(let v=0;v<nv;v++){const s=W[v*4]+W[v*4+1]+W[v*4+2]+W[v*4+3];ws=Math.max(ws,Math.abs(s-1));for(let k=0;k<4;k++)if(W[v*4+k]>0&&J[v*4+k]>=NB)jb++;const l=Math.hypot(N[v*3],N[v*3+1],N[v*3+2]);if(Math.abs(l-1)>1e-3)nl++;}
  // bind check: world rest position of each joint must cancel its inverse bind matrix
  const world=new Array(json.nodes.length),parent={};json.nodes.forEach((n,i)=>(n.children||[]).forEach(c=>parent[c]=i));
  const wp=i=>{if(world[i])return world[i];const t=json.nodes[i].translation||[0,0,0],p=parent[i]!=null?wp(parent[i]):[0,0,0];return world[i]=[t[0]+p[0],t[1]+p[1],t[2]+p[2]];};
  let be=0;sk.joints.forEach((n,k)=>{const w=wp(n);for(let c=0;c<3;c++)be=Math.max(be,Math.abs(w[c]+ibm[k*16+12+c]));});
  const names=new Set(json.nodes.map(n=>n.name));
  const codes={};for(let v=0;v<nv;v++){const c=C[v*4+3]/17;codes[c]=(codes[c]||0)+1;}
  console.log(file.split('/').pop(),'| tris',I.length/3,'verts',nv,'bones',NB,'| max index ok',mi<nv,'| weight sum err',ws.toExponential(1),'| bad joints',jb,'| bad normals',nl,'| bind err',be.toExponential(1),'| unique names',names.size===json.nodes.length,'| anims',(json.animations||[]).length,'| part codes',JSON.stringify(codes));
  return{json,P,N,J,W,I,UV,UV2,C,nv,NB,sk};}
module.exports={readGLB,check};
if(require.main===module)for(const f of['MaleBody_Muscular.glb','MaleBody_Muscular_mid.glb','MaleBody_Muscular_low.glb'])check('./export/'+f);
