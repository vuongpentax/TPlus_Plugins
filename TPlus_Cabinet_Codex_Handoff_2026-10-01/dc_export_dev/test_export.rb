require 'json'
require 'time'
def file_loaded?(_); true; end
module Geom
  class Vector3d
    def to_a; [1,0,0]; end
    def length; 1; end
    def cross(_); self; end
    def dot(_); 1; end
  end
  class Point3d
    def initialize(*xyz); @xyz=xyz; end
    def to_a; @xyz; end
  end
  class Transformation
    def to_a; [1,0,0,0,0,1,0,0,0,0,1,0,2,0,0,1]; end
    def origin; Point3d.new(2,0,0); end
    def xaxis; Vector3d.new; end
    alias yaxis xaxis
    alias zaxis xaxis
  end
end
class Box
  def empty?; false; end
  def min; Geom::Point3d.new(0,0,0); end
  def max; Geom::Point3d.new(10,20,30); end
  def width; 10; end
  def height; 20; end
  def depth; 30; end
end
class Dictionary
  attr_reader :name
  def initialize(name, values, nested=nil); @name,@values,@nested=name,values,nested; end
  def each_pair(&block); @values.each_pair(&block); end
  def attribute_dictionaries; @nested; end
end
module Sketchup
  def self.version; '24.0-test'; end
  def self.active_model; $test_model; end
  class ComponentDefinition
    attr_accessor :entities
    attr_reader :name,:persistent_id
    def initialize(id,name,dicts=[]); @persistent_id,@name,@dicts,@entities=id,name,dicts,[]; end
    def description; 'Mẫu tiếng Việt'; end
    def attribute_dictionaries; @dicts; end
    def bounds; Box.new; end
    def set_attribute(*); raise 'MUTATION'; end
  end
  class ComponentInstance
    attr_reader :persistent_id,:name,:definition
    def initialize(id,name,definition,dicts=[]); @persistent_id,@name,@definition,@dicts=id,name,definition,dicts; end
    def attribute_dictionaries; @dicts; end
    def transformation; Geom::Transformation.new; end
    def typename; self.class.name.split('::').last; end
    def hidden?; true; end
    def locked?; true; end
    def layer; Struct.new(:name).new('T+_CANH'); end
    def material; nil; end
    def bounds; Box.new; end
    def set_attribute(*); raise 'MUTATION'; end
  end
  class Group < ComponentInstance; end
  class Face
    def typename; 'Face'; end
    def persistent_id; 800; end
    def bounds; Box.new; end
    def attribute_dictionaries; [Dictionary.new('test',{'edge'=>'Dán cạnh'})]; end
  end
end
module UI
  def self.messagebox(message); $messages << message; end
  def self.savepanel(*); $save_calls+=1; nil; end
end
class TestModel
  attr_accessor :selection
  def title; 'Tủ tham khảo'; end
  def options; {'UnitsOptions'=>{'LengthUnit'=>2}}; end
  def active_path; nil; end
  def edit_transform; Geom::Transformation.new; end
  def start_operation(*); raise 'MUTATION'; end
end
def assert(ok,msg); raise msg unless ok; end
def run_tests
  formula='IF(parent!lenx>80, parent!lenx/2, 40)'
  child_def=Sketchup::ComponentDefinition.new(20,'Hồi',[Dictionary.new('dynamic_attributes',{'_lenx_formula'=>formula,'lenx'=>40,'_lenx_access'=>'TEXTBOX','_lenx_units'=>'CENTIMETERS'})])
  child_def.entities << Sketchup::Face.new
  shared1=Sketchup::ComponentInstance.new(21,'Hồi trái',child_def,[Dictionary.new('dynamic_attributes',{'lenx'=>45})])
  shared2=Sketchup::ComponentInstance.new(22,'Hồi phải',child_def,[Dictionary.new('dynamic_attributes',{'lenx'=>50,'_x_formula'=>'parent!lenx-lenx'})])
  parent=Sketchup::ComponentDefinition.new(10,'Tủ',[Dictionary.new('custom',{'list'=>[1,true,nil,'é']},[Dictionary.new('nested',{'note'=>'ẩn'})])])
  parent.entities=[shared1,shared2]
  root=Sketchup::Group.new(1,'Tủ mẫu',parent)
  model=TestModel.new;model.selection=[root];$test_model=model
  result=TPlus::DCExporter::Snapshot.new.build(model,[root])
  parsed=JSON.parse(JSON.pretty_generate(result))
  assert(parsed['definitions'].length==2,'Shared definition duplicated')
  assert(parsed['summary']['formula_entries']==2,'Missing formula metadata')
  defrec=parsed['definitions']['definition_20']
  assert(defrec['dc_formulas']['_lenx_formula']==formula,'Formula changed')
  assert(defrec['attribute_dictionaries']['dynamic_attributes']['values']['lenx']==40,'Raw number converted')
  a,b=parsed['definitions']['definition_10']['children']
  assert(a['definition_ref']==b['definition_ref'],'Shared ref lost')
  assert(a['attribute_dictionaries']['dynamic_attributes']['values']['lenx']==45,'Instance value lost')
  assert(b['attribute_dictionaries']['dynamic_attributes']['values']['lenx']==50,'Instance override lost')
  assert(a['hidden']&&a['locked'],'Hidden/locked state lost')
  assert(parsed['definitions']['definition_10']['attribute_dictionaries']['custom']['child_dictionaries']['nested']['values']['note']=='ẩn','Nested dictionary lost')
  assert(defrec['other_entities_with_attributes'][0]['attribute_dictionaries']['test']['values']['edge']=='Dán cạnh','Face attributes lost')
  assert(parsed['roots'][0]['origin_parent_mm']==[50.8,0.0,0.0],'Transform conversion failed')
  assert(defrec['local_bounds_mm']['size_xyz']==[254.0,508.0,762.0],'Bounds conversion failed')
  $messages=[];$save_calls=0
  assert(TPlus::DCExporter.export_selected.nil?,'Cancel should return nil')
  assert($save_calls==1&&$messages.empty?,'Cancel behavior')
  model.selection=[]
  TPlus::DCExporter.export_selected
  assert($save_calls==1&&$messages.length==1,'Empty selection did not stop')
  puts 'PASS: JSON round trip, raw formulas, instance overrides, shared definitions, hidden/locked groups, nested dictionaries, face attributes, mm conversion, cancel and empty selection; no model mutation.'
end
