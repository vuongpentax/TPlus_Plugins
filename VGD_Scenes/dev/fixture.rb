# Simulation only: Ruby orchestration and vector math, not the SketchUp kernel.
require 'json'
require 'fileutils'
module Geom
  class Vector3d
    attr_accessor :x, :y, :z
    def initialize(*args); @x,@y,@z=(args.length==1 ? args[0] : args).map(&:to_f); end
    def to_a; [x,y,z]; end
    def length; Math.sqrt(dot(self)); end
    def dot(v); x*v.x+y*v.y+z*v.z; end
    def cross(v); Vector3d.new(y*v.z-z*v.y,z*v.x-x*v.z,x*v.y-y*v.x); end
    def normalize; raise 'zero vector' if length<1e-12; Vector3d.new(to_a.map { |v| v/length }); end
    def reverse; Vector3d.new(-x,-y,-z); end
    def ==(v); v.respond_to?(:to_a) && to_a.zip(v.to_a).all? { |a,b| (a-b).abs<1e-9 }; end
  end
  class Point3d < Vector3d
    def -(p); Vector3d.new(x-p.x,y-p.y,z-p.z); end
    def offset(v,n); v=v.normalize; Point3d.new(x+v.x*n,y+v.y*n,z+v.z*n); end
    def transform(t); t.point(self); end
  end
  class Transformation
    attr_accessor :m
    def initialize; @m=[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]; end
    def self.rotation_z(degrees)
      t=new; a=degrees*Math::PI/180; t.m=[[Math.cos(a),-Math.sin(a),0,0],[Math.sin(a),Math.cos(a),0,0],[0,0,1,0],[0,0,0,1]];t
    end
    def self.translation(x,y,z); t=new;t.m[0][3]=x;t.m[1][3]=y;t.m[2][3]=z;t; end
    def self.scaling(x,y,z); t=new;t.m[0][0]=x;t.m[1][1]=y;t.m[2][2]=z;t;end
    def *(other); t=self.class.new;4.times { |i| 4.times { |j| t.m[i][j]=(0..3).inject(0.0) { |s,k| s+m[i][k]*other.m[k][j] } } };t;end
    def point(p); Point3d.new(3.times.map { |i| m[i][3]+(0..2).inject(0.0) { |s,j| s+m[i][j]*p.to_a[j] } });end
    def inverse
      rows = m.each_with_index.map { |row,i| row.map(&:to_f) + 4.times.map { |j| i==j ? 1.0 : 0.0 } }
      4.times do |i|
        pivot=(i...4).max_by { |r| rows[r][i].abs };rows[i],rows[pivot]=rows[pivot],rows[i]
        scale=rows[i][i];raise 'singular' if scale.abs<1e-12;rows[i].map! { |v| v/scale }
        4.times { |r| next if r==i;factor=rows[r][i];rows[r]=rows[r].zip(rows[i]).map { |a,b| a-factor*b } }
      end
      t=self.class.new;t.m=rows.map { |r| r[4,4] };t
    end
    def xaxis; Vector3d.new(m[0][0],m[1][0],m[2][0]);end
    def yaxis; Vector3d.new(m[0][1],m[1][1],m[2][1]);end
    def zaxis; Vector3d.new(m[0][2],m[1][2],m[2][2]);end
  end
  class BoundingBox
    def initialize;@p=[];end
    def add(points);@p.concat(Array(points));self;end
    def empty?;@p.empty?;end
    def low;3.times.map { |i| @p.map { |p| p.to_a[i] }.min };end
    def high;3.times.map { |i| @p.map { |p| p.to_a[i] }.max };end
    def corner(i);Point3d.new(3.times.map { |axis| (i & (1<<axis)).zero? ? low[axis] : high[axis] });end
    def center;Point3d.new(low.zip(high).map { |a,b| (a+b)/2.0 });end
  end
  Bounds2d=Struct.new(:x,:y,:width,:height)
end
module Sketchup
  class << self;attr_accessor :active_model,:status_text;end
  class Entity
    @@sequence=0
    attr_accessor :layer,:hidden
    def initialize;@@sequence+=1;@id=@@sequence;@attributes={};@valid=true;@hidden=false;end
    def persistent_id;@id;end
    def valid?;@valid;end
    def invalidate!;@valid=false;end
    def hidden?;@hidden;end
    def get_attribute(d,k,default=nil);(@attributes[d]||{}).fetch(k,default);end
    def set_attribute(d,k,v);(@attributes[d]||={})[k]=v;end
    def delete_attribute(d,k);(@attributes[d]||{}).delete(k);end
  end
  class Drawingelement < Entity;end
  class Image < Drawingelement;end
  class ComponentInstance < Drawingelement
    attr_accessor :definition,:transformation,:name
    def initialize(definition,name='Tủ');super();@definition=definition;definition.instances << self;@transformation=Geom::Transformation.new;@name=name;end
    def locked?;false;end
    def make_unique
      old=definition;old.instances.delete(self)
      copied=Entities.new
      old.entities.each do |e|
        raise 'Fixture supports section planes only for shared leaves' unless e.is_a?(SectionPlane)
        copy=SectionPlane.new(e.plane);copy.name=e.name;copy.layer=e.layer;copy.hidden=e.hidden
        copy.instance_variable_set(:@attributes,Marshal.load(Marshal.dump(e.instance_variable_get(:@attributes))))
        copied << copy;copied.active_section_plane=copy if old.entities.active_section_plane==e
      end
      self.definition=Definition.new(old.bounds,copied,old.name);definition.instances << self;self
    end
  end
  class Group < ComponentInstance;def entities;definition.entities;end;end
  Definition=Struct.new(:bounds,:entities,:name) do
    def instances;@instances ||= [];end
  end
  class SectionPlane < Drawingelement
    attr_accessor :name,:plane
    def initialize(plane);super();@plane=plane;end
    def set_plane(plane);@plane=plane;end
  end
  class Entities < Array
    attr_accessor :active_section_plane
    def add_section_plane(plane);e=SectionPlane.new(plane);self << e;e;end
  end
  class Layer < Entity
    attr_accessor :visible
    def initialize;super;@visible=true;end
    def visible?;@visible;end
  end
  class Layers < Array;def folders;[];end;end
  class Camera
    attr_accessor :eye,:target,:up,:height,:fov,:aspect_ratio
    attr_accessor :two_point,:vertical_fov,:fail_set_once
    def initialize(eye=Geom::Point3d.new(0,-100,100),target=Geom::Point3d.new(0,0,0),up=Geom::Vector3d.new(0,0,1),perspective=false)
      @eye=eye;@target=target;@up=up;@perspective=perspective;@height=80;@fov=35;@aspect_ratio=0.0
    end
    def perspective?;@perspective;end
    def fov_is_height?;@vertical_fov != false;end
    def is_2d?;!!@two_point;end
    def perspective=(value);@perspective=value;end
    def set(eye,target,up)
      if @fail_set_once;@fail_set_once=false;raise 'Simulated camera setter failure';end
      @eye=eye;@target=target;@up=up;self
    end
  end
  class Selection < Array;def add(items);concat(Array(items));end;end
  class Page < Entity
    attr_accessor :name,:use_camera,:use_rendering_options,:use_style,:use_hidden_geometry,:use_hidden_objects,:use_hidden_layers,:use_section_planes,:saved,:fail
    attr_reader :visibility,:tag_visibility
    def initialize(model,name);super();@model=model;@name=name;@visibility={};@tag_visibility={};end
    def update(_flags)
      return false if fail
      if _flags == PAGE_USE_CAMERA && @saved
        @saved[:camera]=VGD::Scenes.camera_copy(@model.active_view.camera)
        return true
      end
      sections=VGD::Scenes::SceneStore.entity_contexts(@model).map { |entities| [entities,entities.active_section_plane] }
      @saved={camera:VGD::Scenes.camera_copy(@model.active_view.camera),rendering:@model.rendering_options.dup,plane:@model.entities.active_section_plane,sections:sections}
      true
    end
    def set_drawingelement_visibility(e,v);@visibility[e]=v;true;end
    def set_visibility(layer,v);@tag_visibility[layer]=v;self;end
    def camera;@saved ? @saved[:camera] : @model.active_view.camera;end
    def use_camera?;!!@use_camera;end
  end
  class Pages < Array
    attr_reader :selected_page
    def initialize(model);@model=model;super();end
    def add(name,flags=nil);p=Page.new(@model,name);self << p;if flags;p.use_camera=true;p.update(flags);end;p;end
    def erase(page);delete(page);page.invalidate!;end
    def selected_page=(page)
      @selected_page=page
      return unless page && page.saved
      @model.active_view.camera=VGD::Scenes.camera_copy(page.saved[:camera]);@model.rendering_options.replace(page.saved[:rendering]);@model.entities.active_section_plane=page.saved[:plane]
      page.saved[:sections].each { |entities,plane| entities.active_section_plane=plane }
      page.visibility.each { |e,v| e.hidden=!v if e.valid? }
      page.tag_visibility.each { |layer,v| layer.visible=v }
    end
  end
  class View
    attr_accessor :camera,:fail_write
    attr_reader :writes
    def initialize;@camera=Camera.new;@writes=[];end
    def invalidate;end
    def refresh;end
    def write_image(opts)
      @last_written_camera=VGD::Scenes.camera_copy(camera)
      @writes << opts
      return false if @fail_write
      File.binwrite(opts[:filename],"PNG fake #{opts[:width]} #{opts[:height]}");true
    end
    attr_reader :last_written_camera
  end
  class Style < Entity;end
  Styles=Struct.new(:selected_style,:active_style)
  class Axes
    attr_reader :origin,:xaxis,:yaxis,:zaxis
    def initialize;set(Geom::Point3d.new(0,0,0),Geom::Vector3d.new(1,0,0),Geom::Vector3d.new(0,1,0),Geom::Vector3d.new(0,0,1));end
    def set(o,x,y,z);@origin=o;@xaxis=x;@yaxis=y;@zaxis=z;end
  end
  class Model < Entity
    attr_reader :entities,:selection,:pages,:layers,:rendering_options,:shadow_info,:styles,:axes,:active_view,:options,:events
    attr_accessor :active_path
    def initialize
      super();@entities=Entities.new;@selection=Selection.new;@pages=Pages.new(self);@layers=Layers.new << Layer.new
      @rendering_options={'DisplaySectionCuts'=>true,'DisplaySectionPlanes'=>true};@shadow_info={};@styles=Styles.new(Style.new,Style.new);@axes=Axes.new;@active_view=View.new
      @options={'PageOptions'=>{'ShowTransition'=>true}};@events=[]
    end
    def title;'Model test';end
    def start_operation(label,_);@events << [:start,label];end
    def commit_operation;@events << [:commit];end
    def abort_operation;@events << [:abort];end
    def select_tool(tool);@tool.deactivate(active_view) if @tool;@tool=tool;tool.activate if tool;end
  end
end
module UI
  @timers={};@seq=0;@toolbars=[]
  class << self
    attr_reader :toolbars
    def messages;@messages ||= [];end
    def messagebox(message);messages << message;end
    attr_accessor :next_directory,:next_savepanel,:next_openpanel
    def select_directory(**_);@next_directory;end
    def savepanel(*);@next_savepanel;end
    def openpanel(*);@next_openpanel;end
    def start_timer(_a,_b,&block);@seq+=1;@timers[@seq]=block;@seq;end
    def stop_timer(id);@timers.delete(id);end
    def drain;1000.times { break if @timers.empty?;key=@timers.keys.first;@timers.delete(key).call };raise 'Timer loop' unless @timers.empty?;end
    def tick;key=@timers.keys.first;@timers.delete(key).call;end
    def menu(_);self;end
    def add_submenu(_);self;end
    def add_item(*);end
    def openURL(*);end
  end
  class Command
    attr_accessor :small_icon,:large_icon,:tooltip,:status_bar_text
    attr_reader :proc
    def initialize(_name,&block);@proc=block;end
  end
  class Toolbar
    attr_reader :events,:commands
    def initialize(*);@events=[];@commands=[];UI.toolbars << self;end
    def add_item(command);@events << :add;@commands << command;end
    def show;@events << :show;end
  end
end
module Layout
  @documents=[]
  class << self;attr_accessor :documents;end
  Image=Struct.new(:path,:bounds)
  Page=Struct.new(:name,:images)
  PageInfo=Struct.new(:width,:height)
  class Pages < Array;def add(name);p=Page.new(name,[]);self << p;p;end;end
  class Document
    attr_reader :pages,:layers,:page_info
    def initialize;@pages=Pages.new;@pages.add('Page 1');@layers=[:layer];@page_info=PageInfo.new;Layout.documents << self;end
    def add_entity(image,_layer,page);page.images << image;end
    def export(path);File.binwrite(path,'%PDF-'+('x'*200));end
  end
end
PAGE_USE_CAMERA=1;PAGE_USE_RENDERING_OPTIONS=2;PAGE_USE_HIDDEN_GEOMETRY=4;PAGE_USE_HIDDEN_OBJECTS=8;PAGE_USE_LAYER_VISIBILITY=16;PAGE_USE_SECTION_PLANES=32
Sketchup.active_model=Sketchup::Model.new
