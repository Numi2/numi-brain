// Cold import adapter. Compiled against the existing NumiLab native asset and
// analytic kinematics owners; no physics or controller stepping is added here.
#include "metalrobo/RunProgram.hpp"
#include "metalrobo/ArticulatedDynamics.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_set>

#ifndef NUMILAB_SOURCE_REVISION
#error "build through export_numilab_robot.py against its pinned native revision"
#endif
namespace {
using V = std::array<double,3>;
using Q = std::array<double,4>;
V xyz(const mr_float4 v) { return {v.x,v.y,v.z}; }
Q quat(const mr_float4 v) { return {v.x,v.y,v.z,v.w}; }
V add(V a,V b) { return {a[0]+b[0],a[1]+b[1],a[2]+b[2]}; }
V scale(V a,double s) { return {a[0]*s,a[1]*s,a[2]*s}; }
V cross(V a,V b) { return {a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]}; }
Q normalized(Q q) {
 double n=0; for(auto x:q) n+=x*x;
 if(!std::isfinite(n)||n<1e-12) throw std::runtime_error("invalid joint quaternion");
 for(auto &x:q) x/=std::sqrt(n); return q;
}
Q conjugate(Q q) { return {-q[0],-q[1],-q[2],q[3]}; }
Q multiply(Q a,Q b) {
 auto v=add(add(scale({b[0],b[1],b[2]},a[3]),scale({a[0],a[1],a[2]},b[3])),cross({a[0],a[1],a[2]},{b[0],b[1],b[2]}));
 return {v[0],v[1],v[2],a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]};
}
V rotate(Q q,V v) { auto t=scale(cross({q[0],q[1],q[2]},v),2);return add(v,add(scale(t,q[3]),cross({q[0],q[1],q[2]},t))); }
Q angle(V axis,double a) { const auto s=std::sin(a/2);return {axis[0]*s,axis[1]*s,axis[2]*s,std::cos(a/2)}; }
struct Joint {
 uint32_t id,parent,child,kind,qIndex;
 V parentAnchor,childAnchor,axis{};
 Q orientation;
 float lower=0,upper=0,rest=0;
};
std::vector<Joint> convert(const metalrobo::EngineModel &m) {
 std::string reason; if(!m.valid(&reason)) throw std::runtime_error(reason);
 if(m.articulations.size()!=1 || m.articulations[0].firstBody!=0 || m.articulations[0].bodyCount!=m.bodies.size())
  throw std::runtime_error("import requires one complete articulation");
 std::vector<Joint> result;
 for(uint32_t i=0;i<m.joints.size();++i) {
  const auto &j=m.joints[i];
  if(j.jointType!=MR_JOINT_FIXED && j.jointType!=MR_JOINT_REVOLUTE && j.jointType!=MR_JOINT_PRISMATIC)
   throw std::runtime_error("joint kind needs an explicit coordinate model; no invented finite limits");
  const bool fixed=j.jointType==MR_JOINT_FIXED;
  if(j.nq!=(fixed?0u:1u)||j.nv!=(fixed?0u:1u)) throw std::runtime_error("native joint coordinate dimensions disagree");
  const auto rp=normalized(quat(j.parentRotation)), rc=normalized(quat(j.childRotation));
  Joint out{i,j.parentBody,j.childBody,fixed?0u:(j.jointType==MR_JOINT_PRISMATIC?2u:1u),j.qOffset,
    xyz(j.parentAnchor),xyz(j.childAnchor),{},multiply(rp,conjugate(rc))};
  if(!fixed) {
   if(j.vOffset>=m.dofs.size()||j.qOffset>=m.defaultQ.size()) throw std::runtime_error("coordinate range missing");
   const auto &d=m.dofs[j.vOffset];
   if(d.jointIndex!=i || d.qIndex!=j.qOffset || d.vIndex!=j.vOffset || d.localDof!=0 ||
      !(d.flags&MR_DOF_FLAG_POSITION_LIMIT)) throw std::runtime_error("coordinate needs exact native ownership and authored bounds");
   out.lower=d.limits.x;out.upper=d.limits.y;out.rest=m.defaultQ[j.qOffset];
   if(!std::isfinite(out.rest)||!std::isfinite(out.lower)||!std::isfinite(out.upper)||
      !(out.lower<out.upper)||out.rest<out.lower||out.rest>out.upper) throw std::runtime_error("invalid authored joint range");
   auto axis=xyz(j.axis0);const double n=std::sqrt(axis[0]*axis[0]+axis[1]*axis[1]+axis[2]*axis[2]);
   if(!std::isfinite(n)||n<1e-12) throw std::runtime_error("invalid joint axis");
   axis=scale(axis,1/n);out.axis=rotate(rp,axis);
   // NumiBrain predicts displacement from rest, unlike native absolute q.
   if(out.kind==1) out.orientation=multiply(multiply(rp,angle(axis,out.rest)),conjugate(rc));
   else out.parentAnchor=add(out.parentAnchor,scale(out.axis,out.rest));
  }
  // Verify the same FP32 values that the JSON consumer will receive.
  for(auto *values:{&out.parentAnchor,&out.childAnchor,&out.axis})
   for(auto &x:*values) x=double(float(x));
  for(auto &x:out.orientation) x=double(float(x));
  result.push_back(out);
 }
 return result;
}
// Compare the transferred displacement-from-rest convention to the EXISTING
// native FP64 kinematics at rest and a simultaneous bounded coordinate change.
void verify(const metalrobo::EngineModel &m,const std::vector<Joint> &joints) {
 std::vector<double> q(m.defaultQ.begin(),m.defaultQ.end()), v(m.defaultV.begin(),m.defaultV.end());
 for(unsigned sample=0;sample<3;++sample) {
  if(sample) for(const auto &j:joints) if(j.kind)
   q[j.qIndex]=std::clamp(double(j.rest)+(sample==1?1:-1)*(j.kind==1?0.031:0.001),double(j.lower),double(j.upper));
  std::vector<metalrobo::ArticulatedBodyKinematics> bodies(m.bodies.size());
  const auto status=metalrobo::computeArticulatedBodyKinematics(m,0,q,v,bodies);
  if(!status.succeeded()) throw std::runtime_error("native reference kinematics rejected imported asset");
  for(const auto &j:joints) {
   const auto &p=bodies.at(j.parent), &c=bodies.at(j.child);
   const double delta=j.kind?q.at(j.qIndex)-j.rest:0;
   auto r=multiply(p.orientation,multiply(j.kind==1?angle(j.axis,delta):Q{0,0,0,1},j.orientation));
   auto x=add(p.centerOfMassPosition,add(rotate(p.orientation,add(j.parentAnchor,j.kind==2?scale(j.axis,delta):V{})),scale(rotate(r,j.childAnchor),-1)));
   double err=0;for(size_t a=0;a<3;++a) err=std::max(err,std::abs(x[a]-c.centerOfMassPosition[a]));
   // Quaternions q and -q describe the same orientation.
   double dot=0;for(size_t a=0;a<4;++a) dot+=r[a]*c.orientation[a];
   if(err>1e-6 || std::abs(std::abs(dot)-1)>1e-6) throw std::runtime_error("transferred joint frame differs from native kinematics");
  }
 }
}
std::string quoted(const std::string &value) {
 std::ostringstream s;s<<'"';
 for(unsigned char c:value) {
  if(c=='"'||c=='\\') s<<'\\'<<char(c);
  else if(c<32) s<<"\\u"<<std::hex<<std::setw(4)<<std::setfill('0')<<unsigned(c)<<std::dec;
  else s<<char(c);
 }
 s<<'"';return s.str();
}
void point(std::ostream &s,V v) {s<<"{\"x\":"<<v[0]<<",\"y\":"<<v[1]<<",\"z\":"<<v[2]<<'}';}
void quaternion(std::ostream &s,Q q) {s<<"{\"x\":"<<q[0]<<",\"y\":"<<q[1]<<",\"z\":"<<q[2]<<",\"w\":"<<q[3]<<'}';}
void names(std::ostream &s,const std::vector<std::string> &values) {s<<'[';bool first=true;for(auto &v:values){if(!first)s<<',';first=false;s<<quoted(v);}s<<']';}
std::string exportRobot(const metalrobo::RobotPack &pack) {
 const auto &m=pack.mechanics;const auto joints=convert(m);verify(m,joints);
 if(pack.actuators.empty()||pack.actuators.size()>4096) throw std::runtime_error("robot has no bounded authored actuator interface");
 std::ostringstream s;s.imbue(std::locale::classic());s<<std::setprecision(std::numeric_limits<float>::max_digits10);
 s<<"{\"version\":1,\"nativeRepositoryRevision\":"<<quoted(NUMILAB_SOURCE_REVISION)<<",\"robotID\":"<<quoted(pack.id)
  <<",\"sourceRepository\":"<<quoted(pack.sourceRepository)<<",\"sourceRevision\":"<<quoted(pack.sourceRevision)<<",\"license\":"<<quoted(pack.license)
  <<",\"bodyNames\":";names(s,m.bodyNames);s<<",\"jointNames\":";names(s,m.jointNames);s<<",\"joints\":[";
 bool first=true;for(const auto &j:joints) {
  if(!first)s<<',';first=false;
  s<<"{\"jointIdentifier\":"<<j.id<<",\"parentBodyIdentifier\":"<<j.parent<<",\"childBodyIdentifier\":"<<j.child<<",\"parentLocalAnchor\":";point(s,j.parentAnchor);
  s<<",\"childLocalAnchor\":";point(s,j.childAnchor);s<<",\"restRelativeOrientation\":";quaternion(s,j.orientation);s<<",\"coordinates\":[";
  if(j.kind) {s<<"{\"identifier\":0,\"kind\":"<<j.kind<<",\"parentLocalAxis\":";point(s,j.axis);s<<",\"minimumPosition\":"<<j.lower<<",\"maximumPosition\":"<<j.upper<<",\"restPosition\":"<<j.rest<<'}';}
  s<<"]}";
 }
 s<<"],\"actuators\":[";first=true;std::unordered_set<std::string> ids;
 for(const auto &a:pack.actuators) {
  if(a.id.empty()||!ids.insert(a.id).second||!std::isfinite(a.scale)||!std::isfinite(a.responseTimeSeconds)||a.responseTimeSeconds<0)
   throw std::runtime_error("invalid authored actuator identity or scale");
  if(!first)s<<',';first=false;
  s<<"{\"id\":"<<quoted(a.id)<<",\"kind\":"<<uint32_t(a.kind)<<",\"target\":"<<quoted(a.target)<<",\"scale\":"<<a.scale<<",\"responseTimeSeconds\":"<<a.responseTimeSeconds<<",\"component\":"<<a.component<<",\"parameters\":[";
  const auto p=a.parameters;const std::array<float,4> pars{p.x,p.y,p.z,p.w};
  for(size_t i=0;i<4;++i){if(!std::isfinite(pars[i]))throw std::runtime_error("nonfinite actuator parameter");if(i)s<<',';s<<pars[i];}
  s<<"],\"terms\":[";bool ft=true;for(const auto &t:a.terms){if(!std::isfinite(t.coefficient))throw std::runtime_error("nonfinite actuator term");if(!ft)s<<',';ft=false;s<<"{\"joint\":"<<quoted(t.joint)<<",\"coefficient\":"<<t.coefficient<<'}';}s<<"]}";
 }
 s<<"],\"nativeKinematicsSamples\":3,\"scope\":\"topology-and-actuator-metadata-only\"}\n";return s.str();
}
}
int main(int argc,char **argv) {
 try {
  if(argc!=2) throw std::runtime_error("usage: export_numilab_robot ROBOT_ID");
  auto pack=metalrobo::builtinRobotPack(argv[1]);if(!pack) throw std::runtime_error("robot not in the native catalog");
  const auto text=exportRobot(*pack);std::cout<<text;return 0;
 }catch(const std::exception &e){std::cerr<<e.what()<<'\n';return 1;}
}
