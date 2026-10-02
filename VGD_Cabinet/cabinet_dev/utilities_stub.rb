# API fixtures for utility scope/attributes/selection; not a native geometry kernel.
require 'set'
module Geom
  Point3d = Struct.new(:x, :y, :z)
  class Transformation
    attr_reader :offset
    def initialize(offset = [0, 0, 0]); @offset = offset; end
    def *(other); self.class.new(offset.zip(other.offset).map { |a, b| a + b }); end
  end
end
module Sketchup
  class SelectionObserver; end
  Layer = Struct.new(:name)
  class Dictionary < Hash
    attr_reader :name
    def initialize(name); super(); @name = name; end
  end
  class Dictionaries < Hash
    def each; values.each { |dictionary| yield dictionary }; end
  end
  class Entity
    attr_accessor :name, :layer, :material, :transformation, :hidden, :locked, :collection
    def initialize
      @name = ''; @layer = Sketchup.active_model.layers[0]; @material = nil
      @transformation = Geom::Transformation.new; @hidden = false; @locked = false
      @valid = true; @dictionaries = Dictionaries.new
    end
    def valid?; @valid; end
    def hidden?; @hidden; end
    def visible?; !@hidden; end
    def locked?; @locked; end
    def parent; collection.owner; end
    def attribute_dictionaries; @dictionaries; end
    def set_attribute(dict, key, value)
      (@dictionaries[dict] ||= Dictionary.new(dict))[key] = value
    end
    def get_attribute(dict, key, fallback = nil); (@dictionaries[dict] || {}).fetch(key, fallback); end
    def erase!
      @valid = false; collection.delete(self) if collection
      definition.instances.delete(self) if respond_to?(:definition)
    end
    def fixture_copy
      copy = dup; copy.instance_variable_set(:@valid, true)
      dictionaries = Dictionaries.new
      @dictionaries.each do |dictionary|
        dictionaries[dictionary.name] = Dictionary.new(dictionary.name).merge!(dictionary)
      end
      copy.instance_variable_set(:@dictionaries, dictionaries)
      copy.definition.instances << copy if copy.respond_to?(:definition)
      copy
    end
  end
  class Definition < Entity
    attr_reader :entities, :instances
    def initialize(name = '')
      super(); @name = name; @entities = Entities.new(self); @instances = []
    end
    def fixture_copy
      copy = super
      copy.instance_variable_set(:@instances, [])
      contents = Entities.new(copy)
      entities.each { |entity| contents.attach(entity.fixture_copy) }
      copy.instance_variable_set(:@entities, contents); copy
    end
  end
  module Container
    attr_reader :definition
    def initialize(definition = Definition.new)
      super(); @definition = definition; definition.instances << self
    end
    def make_unique
      if definition.instances.size > 1
        previous = definition; @definition = previous.fixture_copy
        previous.instances.delete(self); @definition.instances << self
      end
      self
    end
    def explode
      raise 'Fixture explode failure' if name == 'FAIL_EXPLODE'
      contents = definition.entities.map do |entity|
        copy = entity.fixture_copy
        copy.transformation = transformation * copy.transformation
        collection.attach(copy); copy
      end
      erase!; contents
    end
  end
  class Group < Entity
    include Container
    def entities; definition.entities; end
  end
  class ComponentInstance < Entity
    include Container
  end
  class Edge < Entity; end
  class Face < Entity; end
  class ConstructionLine < Entity; end
  class ConstructionPoint < Entity; end
  class Entities < Array
    attr_reader :owner
    def initialize(owner); super(); @owner = owner; end
    def attach(entity); entity.collection = self; self << entity; entity; end
    def add_group; attach(Group.new); end
    def add_instance(definition, transformation)
      instance = attach(ComponentInstance.new(definition)); instance.transformation = transformation; instance
    end
    def erase_entities(items); items.each(&:erase!); end
  end
  class Selection < Array
    attr_reader :observers
    def initialize; super; @observers = []; end
    def add(entity); self << entity unless include?(entity); end
    def add_observer(observer); @observers << observer; end
    def remove_observer(observer); @observers.delete(observer); end
  end
  class View
    attr_reader :invalidations
    def initialize; @invalidations = 0; end
    def invalidate; @invalidations += 1; end
  end
  class Model
    attr_reader :layers, :selection, :active_entities, :active_view, :operations, :commits, :aborts
    def initialize
      @layers = {0 => Layer.new('Layer0')}; @selection = Selection.new
      @active_entities = Entities.new(self); @active_view = View.new
      @operations = @commits = @aborts = 0
    end
    def entities; active_entities; end
    def start_operation(*); @operations += 1; end
    def commit_operation; @commits += 1; end
    def abort_operation; @aborts += 1; end
  end
  def self.active_model; @model; end
  def self.read_default(*args); args.last; end
  def self.reset; @model = Model.new; UI.messages.clear; @model; end
end
module UI
  @messages = []; @toolbars = []; @menus = {}; @context_handlers = []
  class << self
    attr_reader :messages, :toolbars, :menus, :context_handlers
    def messagebox(message); messages << message; end
    def menu(name); menus[name] ||= Menu.new(name); end
    def add_context_menu_handler(&block); context_handlers << block; end
  end
  class Command
    attr_accessor :small_icon, :large_icon, :tooltip, :status_bar_text
    attr_reader :name
    def initialize(name, &block); @name = name; @block = block; end
    def call; @block.call; end
    def menu_text; name; end
  end
  class Menu
    attr_reader :name, :items
    def initialize(name); @name = name; @items = []; end
    def add_submenu(name); menu = Menu.new(name); items << menu; menu; end
    def add_item(command, &block); items << command; end
  end
  class Toolbar < Menu
    def initialize(name); super(name); UI.toolbars << self; end
    def restore; @restored = true; end
    def each(&block); items.each(&block); end
  end
  class HtmlDialog
    STYLE_DIALOG = 0
    attr_reader :callbacks, :closed_callback, :html
    def initialize(**); @visible = false; @callbacks = {}; end
    def set_html(html); @html = html; end
    def set_on_closed(&block); @closed_callback = block; end
    def add_action_callback(name, &block); callbacks[name] = block; end
    def show; @visible = true; end
    def visible?; @visible; end
    def bring_to_front; end
    def close; @visible = false; @closed_callback.call if @closed_callback; end
  end
end
$fixture_loaded_files = Set.new
def file_loaded?(name); $fixture_loaded_files.include?(name); end
def file_loaded(name); $fixture_loaded_files.add(name); end
Sketchup.reset
