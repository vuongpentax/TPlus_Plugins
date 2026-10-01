class Numeric
  def mm; self / 25.4; end
  def inch; self.to_f; end
end
module Geom
  class Point3d
    attr_accessor :x,:y,:z
    def initialize(*p); @x,@y,@z=p.flatten; end
    def to_a; [x,y,z]; end
  end
  class Vector3d < Point3d; end
  class Transformation
    attr_reader :offset
    def initialize(p=[0,0,0]); @offset=p.respond_to?(:to_a) ? p.to_a : p; end
    def self.translation(p); new(p); end
    def +(other); self.class.new(offset.zip(other.offset).map { |a,b| a+b }); end
  end
end
module Sketchup
  class SelectionObserver; end
  class Entity
    attr_accessor :name,:layer,:transformation,:material
    def initialize; @name=''; @layer='dirty'; @attrs={}; @transformation=Geom::Transformation.new; end
    def set_attribute(dict,key,value); (@attrs[dict]||={})[key]=value; end
    def get_attribute(dict,key,fallback=nil); (@attrs[dict]||{}) .fetch(key,fallback); end
    def valid?; true; end
    def erase!; end
    def transform!(tr); @transformation=@transformation+tr; end
  end
  Vertex=Struct.new(:position)
  class Face < Entity
    attr_reader :points,:normal
    def initialize(pts)
      super(); @points=pts.map { |p| p.respond_to?(:to_a) ? p.to_a : p }
      a,b,c=@points.first(3)
      u=b.zip(a).map { |x,y| x-y }; v=c.zip(a).map { |x,y| x-y }
      n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
      length=Math.sqrt(n.sum { |x| x*x }); raise 'Degenerate face' if length < 1e-10
      @normal=Geom::Vector3d.new(n.map { |x| x/length })
    end
    def reverse!; @normal=Geom::Vector3d.new(normal.to_a.map { |x| -x }); end
    def pushpull(distance)
      @points+=@points.map { |p| p.zip(normal.to_a).map { |a,n| a+n*distance } }
    end
    def vertices; points.map { |p| Vertex.new(Geom::Point3d.new(p)) }; end
  end
  class Edge < Entity; end
  class ConstructionLine < Entity
    attr_reader :ends
    def initialize(a,b); super(); @ends=[a,b]; end
  end
  class Entities < Array
    def add_group; e=Group.new; self << e; e; end
    def add_face(p); e=Face.new(p); self << e; e; end
    def add_cline(a,b); e=ConstructionLine.new(a,b); self << e; e; end
    def transform_entities(tr,items); items.each { |e| e.transform!(tr) }; end
  end
  class Group < Entity
    attr_accessor :entities,:definition
    def initialize
      super(); @entities=Entities.new; @definition=Definition.new(@entities)
    end
    def to_component
      @definition=Definition.new(@entities); self
    end
  end
  class ComponentInstance < Group; end
  class Definition < Entity
    attr_reader :entities
    def initialize(e); super(); @entities=e; end
  end
  class Layers < Hash
    def initialize; super; self[0]='Untagged'; end
    def add(n); self[n]=n; end
  end
  class Model
    attr_reader :layers,:selection,:operations,:materials
    def initialize; @layers=Layers.new; @selection=[]; @operations=0; @materials=Materials.new; end
    def start_operation(*_); @operations+=1; end
  end
  class Color
    attr_reader :rgb
    def initialize(*rgb); @rgb=rgb; end
  end
  class Material
    attr_accessor :color,:alpha
  end
  class Materials < Hash
    def add(name); self[name]=Material.new; end
  end
  def self.active_model; @model ||= Model.new; end
  def self.read_default(*a); a.last; end
end
module UI
  def self.messagebox(m); puts "UI: #{m}"; end
end
def file_loaded?(*_); true; end
