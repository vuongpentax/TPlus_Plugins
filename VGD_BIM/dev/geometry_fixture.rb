# Simulation of affine math only; the native SketchUp smoke test remains authoritative.
module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x,y,z); @x,@y,@z=x,y,z; end
    def to_a; [x,y,z]; end
    def length; Math.sqrt(x*x+y*y+z*z); end
    def cross(v); Vector3d.new(y*v.z-z*v.y,z*v.x-x*v.z,x*v.y-y*v.x); end
  end
  class Point3d < Vector3d
    def transform(t); t.point(self); end
    def distance(p); Vector3d.new(x-p.x,y-p.y,z-p.z).length; end
  end
  class Transformation
    attr_accessor :m
    def initialize; @m=[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]; end
    def self.scaling(x,y,z); t=new; t.m[0][0]=x;t.m[1][1]=y;t.m[2][2]=z;t;end
    def self.rotation_z(angle); t=new;a=angle*Math::PI/180;t.m[0][0]=Math.cos(a);t.m[1][0]=Math.sin(a);t.m[0][1]=-Math.sin(a);t.m[1][1]=Math.cos(a);t;end
    def *(other); t=self.class.new;4.times { |i| 4.times { |j| t.m[i][j]=4.times.inject(0.0) { |sum,k| sum+m[i][k]*other.m[k][j] } } };t;end
    def point(p); Point3d.new(*3.times.map { |i| m[i][3]+3.times.inject(0.0) { |sum,j| sum+m[i][j]*p.to_a[j] } });end
    def xaxis; Vector3d.new(m[0][0],m[1][0],m[2][0]);end
    def yaxis; Vector3d.new(m[0][1],m[1][1],m[2][1]);end
    def zaxis; Vector3d.new(m[0][2],m[1][2],m[2][2]);end
  end
  Box = Struct.new(:width,:height,:depth) do
    def empty?; width == 0 && height == 0 && depth == 0; end
  end
end
module Sketchup
  class Entities < Array
    attr_accessor :parent
  end
  Definition = Struct.new(:name,:bounds,:entities)
  class ComponentInstance
    attr_accessor :definition,:transformation,:name,:material,:layer,:locked
    alias geometry_original_initialize initialize
    def initialize(model, definition = nil)
      geometry_original_initialize(model)
      @definition=definition;@transformation=Geom::Transformation.new;@name='';@material=nil;@layer=Struct.new(:name).new('Untagged');@locked=false
    end
    def locked?; @locked; end
  end
  class Group
    def entities; definition.entities; end
  end
  class Model
    attr_accessor :entities, :materials, :layers, :selection, :active_path
    def edit_transform; Geom::Transformation.new; end
  end
  class Face
    attr_accessor :material,:back_material
    def initialize; @material=nil;@back_material=nil;end
    def valid?; true; end
    def area(transform); transform.xaxis.cross(transform.yaxis).length * (1000.0/25.4)*(2000.0/25.4);end
  end
  class Edge
    def valid?; true; end
    def start; Struct.new(:position).new(Geom::Point3d.new(0,0,0));end
    def end; Struct.new(:position).new(Geom::Point3d.new(1000.0/25.4,0,0));end
  end
end
