# Simulation only: cannot certify SketchUp geometry/Undo.
require 'json'
module Length; Decimal=0; end
class Numeric; def mm; to_f/25.4; end; end
module Geom
  class Vector3d
    attr_accessor :x,:y,:z
    def initialize(*a); @x,@y,@z=(a.length==1 && a[0].is_a?(Array) ? a[0] : a); @y||=0.0; @z||=0.0; end
    def to_a; [x,y,z]; end
    def length; Math.sqrt(dot(self)); end
    def length=(n); r=n/length; @x*=r; @y*=r; @z*=r; end
    def normalize!; self.length=1.0; self; end
    def normalize; clone.normalize!; end
    def +(b); Vector3d.new(x+b.x,y+b.y,z+b.z); end
    def -(b); Vector3d.new(x-b.x,y-b.y,z-b.z); end
    def reverse; Vector3d.new(-x,-y,-z); end
    def dot(b); x*b.x+y*b.y+z*b.z; end
    def cross(b); Vector3d.new(y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x); end
    def transform(t); t.vector(self); end
  end
  class Point3d < Vector3d
    def +(b); Point3d.new(x+b.x,y+b.y,z+b.z); end
    def -(b); b.is_a?(Point3d) ? Vector3d.new(x-b.x,y-b.y,z-b.z) : Point3d.new(x-b.x,y-b.y,z-b.z); end
    def distance(p); (self-p).length; end
    def vector_to(p); p-self; end
    def transform(t); t.point(self); end
    def self.linear_combination(a,p,b,q); new(a*p.x+b*q.x,a*p.y+b*q.y,a*p.z+b*q.z); end
  end
  class Transformation
    attr_reader :matrix
    def initialize(s=1.0); @matrix=[[s,0,0,0],[0,s,0,0],[0,0,s,0],[0,0,0,1]]; end
    def scale; matrix[0][0]; end
    def self.scaling(s); new(s); end
    def self.translation(v); t=new; 3.times { |i| t.matrix[i][3]=v[i] }; t; end
    def self.axes(p,x,y,z); t=new; 3.times { |i| [x,y,z,p].each_with_index { |v,j| t.matrix[i][j]=v.to_a[i] } }; t; end
    def *(b); t=Transformation.new; 4.times { |i| 4.times { |j| t.matrix[i][j]=(0..3).sum { |k| matrix[i][k]*b.matrix[k][j] } } }; t; end
    def vector(v); Vector3d.new(3.times.map { |i| (0..2).sum { |j| matrix[i][j]*v.to_a[j] } }); end
    def point(p); v=vector(p); Point3d.new(3.times.map { |i| v.to_a[i]+matrix[i][3] }); end
    def inverse; Transformation.new(1.0/scale); end
  end
  class PolygonMesh
    NO_SMOOTH_OR_HIDE=0
    attr_reader :polygons
    def initialize; @polygons=[]; end
    def add_polygon(points); polygons << points; end
  end
  class Bounds
    def initialize(p); @points=p.empty? ? [Point3d.new(0,0,0)] : p; end
    def min; Point3d.new(3.times.map { |i| @points.map { |p| p.to_a[i] }.min }); end
    def max; Point3d.new(3.times.map { |i| @points.map { |p| p.to_a[i] }.max }); end
    def center; Point3d.linear_combination(0.5,min,0.5,max); end
    def width; max.x-min.x; end
  end
end
module UI
  @timers={}; @sequence=0; @menus=[]; @toolbars=[]
  class << self
    attr_reader :timers,:menus,:toolbars
    def start_timer(*,&b); @sequence+=1; @timers[@sequence]=b; @sequence; end
    def stop_timer(id); @timers.delete(id); end
    def drain; 20.times { break if @timers.empty?; b=@timers.values; @timers={}; b.each(&:call) }; raise 'Timer loop' unless @timers.empty?; end
    def menu(_); self; end
    def add_item(item,&b); @menus << [item,b]; end
  end
  class Command
    attr_accessor :small_icon,:large_icon,:tooltip,:status_bar_text
    def initialize(*,&b); @block=b; end
  end
  class Toolbar
    attr_reader :events
    def initialize(*); @events=[]; UI.toolbars << self; end
    def add_item(*); @events << :add; end
    def show; @events << :show; end
    def restore; @events << :restore; end
    def hide; @events << :hide; end
  end
end
$loaded_files={}
def file_loaded?(p); $loaded_files[p]; end
def file_loaded(p); $loaded_files[p]=true; end
module Sketchup
  class SelectionObserver; end
  class EntitiesObserver; end
  class ModelObserver; end
  class AppObserver; end
  class DefinitionsObserver; end
  class << self
    attr_accessor :active_model
    def platform; :platform_other; end
    def read_default(*a); a.last; end
    def write_default(*); end
    def add_observer(*); end
    def remove_observer(*); end
  end
  class Entity
    @@next_id=0
    attr_accessor :parent,:model,:layer,:material,:hidden
    def initialize; @@next_id+=1; @pid=@@next_id; @attrs={}; @valid=true; @hidden=false; end
    def persistent_id; @pid; end
    def valid?; @valid; end
    def hidden?; @hidden; end
    def erase!; @valid=false; parent.delete(self) if parent; end
    def get_attribute(d,k,v=nil); (@attrs[d]||{}).fetch(k,v); end
    def set_attribute(d,k,v); (@attrs[d]||={})[k]=v; end
    def delete_attribute(d,k=nil); k ? @attrs[d]&.delete(k) : @attrs.delete(d); end
    def copy_to(p); c=dup; @@next_id+=1; c.instance_variable_set(:@pid,@@next_id); c.instance_variable_set(:@attrs,Marshal.load(Marshal.dump(@attrs))); c.parent=p; c.model=p.model; c; end
    def points; []; end
  end
  class Edge < Entity
    attr_accessor :vertices
    def initialize(p); super(); @vertices=p; end
    def points; vertices; end
  end
  class Face < Entity
    attr_accessor :vertices,:back_material
    def initialize(p); super(); @vertices=p; end
    def points; vertices; end
  end
  class Entities < Array
    attr_accessor :model,:parent
    def initialize(m,list=[]); @model=m; super(); list.each { |e| self << e }; end
    def <<(e); e.parent=self; e.model=model; super; end
    def add_observer(*); end
    def remove_observer(*); end
    def add_group; d=Definition.new(model); model.definitions << d; g=Group.new(d); self << g; g; end
    def add_line(a,b); e=Edge.new([a,b]); self << e; e; end
    def add_edges(*p); p.each_cons(2).map { |a,b| add_line(a,b) }; end
    def add_circle(p,n,r,s); a=Geom::Point3d.new(p.x+r,p.y,p.z); b=Geom::Point3d.new(p.x,p.y+r,p.z); [add_line(p,a),add_line(a,b),add_line(b,p)]; end
    def add_face(*p); p=p.first if p.length==1; p=p.flat_map(&:points) if p.first.is_a?(Edge); f=Face.new(p); self << f; f; end
    def add_faces_from_mesh(mesh,*); mesh.polygons.each { |t| add_face(t) }; end
    def transform_entities(t,list); list.each { |e| e.vertices=e.points.map { |p| p.transform(t) } if e.respond_to?(:vertices=) }; end
  end
  class Definitions < Array
    def add_observer(*); end
    def remove_observer(*); end
  end
  class Definition
    attr_accessor :entities,:instances
    def initialize(m,list=[]); @entities=Entities.new(m,list); entities.parent=self; @instances=[]; end
  end
  class ComponentInstance < Entity
    attr_accessor :definition,:transformation,:locked,:name
    def initialize(d,s=1.0); super(); @definition=d; d.instances << self; @model=d.entities.model; @transformation=Geom::Transformation.new(s); @locked=false; end
    def locked?; @locked; end
    def make_unique
      old=definition; old.instances.delete(self); @definition=Definition.new(model); definition.instances << self; model.definitions << definition
      old.entities.each { |e| c=e.copy_to(definition.entities); c.definition.instances << c if c.is_a?(ComponentInstance); definition.entities << c }; self
    end
    def points; definition.entities.flat_map(&:points).map { |p| p.transform(transformation) }; end
    def bounds; Geom::Bounds.new(points); end
  end
  class Group < ComponentInstance; def entities; definition.entities; end; end
  class Dimension < Entity
    ARROW_NONE=0; ARROW_SLASH=1; ARROW_DOT=2; ARROW_CLOSED=3; ARROW_OPEN=4
    attr_accessor :arrow_type,:text
    def initialize; super(); @arrow_type=4; @text=''; @aligned=false; end
    def has_aligned_text=(v); @aligned=v; end
    def has_aligned_text?; @aligned; end
  end
  class DimensionLinear < Dimension
    ALIGNED_TEXT_ABOVE=0; ALIGNED_TEXT_CENTER=1; ALIGNED_TEXT_OUTSIDE=2
    attr_accessor :aligned_text_position,:start_point,:end_point
    def initialize; super; @vector=Geom::Vector3d.new(0,2,0); @start_point=Geom::Point3d.new(0,0,0); @end_point=Geom::Point3d.new(800.mm,0,0); end
    def offset_vector; @vector.clone; end
    def offset_vector=(v); @vector=v; end
    def start; [nil,start_point]; end
    def end; [nil,end_point]; end
  end
  class DimensionRadial < Dimension; end
  class Text < Entity
    attr_accessor :arrow_type,:text,:point,:vector,:leader
    def initialize; super; @text='Kích thước tủ'; @arrow_type=0; @point=Geom::Point3d.new(0,0,0); @vector=Geom::Vector3d.new(5,3,0); end
    def has_leader?; @leader!=false; end
  end
  Color=Struct.new(:red,:green,:blue)
  Material=Struct.new(:name,:color)
  class Materials
    attr_reader :items
    def initialize; @items={}; end
    def [](n); items[n]; end
    def add(n); n+='_' while items.key?(n); items[n]=Material.new(n,Color.new(0,0,0)); end
  end
  class Layers < Hash; def add(n); self[n]=n; end; end
  class Selection < Array
    def add_observer(*); end
    def remove_observer(*); end
    def add(entity); self << entity unless include?(entity); end
    def remove(entity); delete(entity); end
  end
  class Camera
    def up; Geom::Vector3d.new(0,1,0); end
    def xaxis; Geom::Vector3d.new(1,0,0); end
  end
  class FakeModel < Entity
    attr_accessor :selection,:active_path
    attr_reader :entities,:definitions,:materials,:layers,:options,:operations,:aborts,:commits,:operation_flags
    def initialize
      super; @model=self; @selection=Selection.new; @definitions=Definitions.new; @entities=Entities.new(self)
      @materials=Materials.new; @layers=Layers.new; @options={'UnitsOptions'=>{'LengthUnit'=>0,'LengthFormat'=>1}}
      @operations=@aborts=@commits=0; @operation_flags=[]
    end
    def guid; "model-#{persistent_id}"; end
    def edit_transform; Geom::Transformation.new; end
    def active_view; self; end
    def camera; Camera.new; end
    def add_observer(*); end
    def remove_observer(*); end
    def invalidate; end
    def start_operation(*a); @operations+=1; @operation_flags<<a; end
    def commit_operation; @commits+=1; end
    def abort_operation; @aborts+=1; end
  end
end
Sketchup.active_model=Sketchup::FakeModel.new
