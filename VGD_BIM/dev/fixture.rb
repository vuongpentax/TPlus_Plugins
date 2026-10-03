require 'json'
module Sketchup
  class Model
    attr_reader :commits, :aborts, :starts
    def initialize; @attributes = {}; @commits = @aborts = @starts = 0; end
    def start_operation(*args); @starts += 1; end
    def commit_operation; @commits += 1; end
    def abort_operation; @aborts += 1; end
    def set_attribute(dict, key, value); (@attributes[dict] ||= {})[key] = value; end
    def get_attribute(dict, key, default = nil); (@attributes[dict] || {}).fetch(key, default); end
  end
  class ComponentInstance
    attr_reader :model
    def initialize(model); @model = model; @attributes = {}; end
    def valid?; true; end
    def locked?; false; end
    def attribute_dictionary(dict, create = false); @attributes[dict]; end
    def get_attribute(dict, key, default = nil); (@attributes[dict] || {}).fetch(key, default); end
    def set_attribute(dict, key, value); (@attributes[dict] ||= {})[key] = value; end
    def delete_attribute(dict); @attributes.delete(dict); end
  end
  class Group < ComponentInstance; end
  def self.active_model; @model ||= Model.new; end
end
module VGD
  module BIM
    def self.log(text); puts text; end
    def self.presets
      [{ 'name' => 'Socket', 'category' => 'electrical', 'item_type' => 'socket', 'unit' => 'pcs', 'quantity_method' => 'count', 'include_boq' => true },
       { 'name' => 'Wardrobe', 'category' => 'furniture', 'item_type' => 'wardrobe', 'unit' => 'set', 'quantity_method' => 'assembly', 'include_boq' => true }]
    end
  end
end
