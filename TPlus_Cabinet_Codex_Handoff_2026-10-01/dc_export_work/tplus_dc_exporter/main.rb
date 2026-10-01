# encoding: UTF-8
# Can also be loaded directly through Ruby Console: load 'C:/path/main.rb'
require 'sketchup.rb'
require 'json'
require 'time'

module TPlus
  module DCExporter
    VERSION = '1.0.0' unless const_defined?(:VERSION)

    class Snapshot
      def initialize
        @definitions = {}
        @warnings = []
        @formula_count = 0
        @container_count = 0
        @attributed_geometry_count = 0
      end

      def text(value)
        value.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
      end

      # DC numeric/string values remain raw. Only actual SketchUp Length objects
      # carry explicit unit conversion; do not reinterpret arbitrary DC numbers.
      def value(raw)
        if defined?(Length) && raw.is_a?(Length)
          return {'type' => 'Length', 'inches' => raw.to_f, 'mm' => raw.to_f * 25.4}
        end
        case raw
        when NilClass, TrueClass, FalseClass, Integer then raw
        when Float
          return raw if raw.finite?
          @warnings << 'Non-finite numeric attribute encoded as a typed string.'
          {'type' => 'Float', 'value' => raw.to_s}
        when String then text(raw)
        when Array then raw.map { |item| value(item) }
        when Hash
          raw.each_with_object({}) { |(key, item), result| result[text(key)] = value(item) }
        when Time then {'type' => 'Time', 'iso8601' => raw.iso8601(6)}
        when Geom::Point3d
          {'type' => 'Geom::Point3d', 'inches' => raw.to_a.map(&:to_f), 'mm' => mm_point(raw)}
        when Geom::Vector3d
          {'type' => 'Geom::Vector3d', 'raw' => raw.to_a.map(&:to_f)}
        else
          @warnings << "Attribute type #{raw.class} was represented as text."
          {'type' => raw.class.name, 'text' => text(raw)}
        end
      end

      def dictionaries(entity)
        collection = entity.attribute_dictionaries
        return {} unless collection
        collection.each_with_object({}) do |dictionary, result|
          entries = {}
          dictionary.each_pair { |key, raw| entries[text(key)] = value(raw) }
          result[text(dictionary.name)] = {
            'values' => entries,
            'child_dictionaries' => dictionaries(dictionary)
          }
        end
      end

      def formulas(attributes)
        dc = attributes.fetch('dynamic_attributes', {}).fetch('values', {})
        result = dc.select { |key, _| key =~ /_formula\z/i }
        @formula_count += result.length
        result
      end

      def mm_point(point)
        point.to_a.map { |coordinate| coordinate.to_f * 25.4 }
      end

      def bounds(box)
        return nil if box.empty?
        {
          'min' => mm_point(box.min), 'max' => mm_point(box.max),
          'size_xyz' => [box.width, box.height, box.depth].map { |n| n.to_f * 25.4 }
        }
      end

      def id(entity)
        entity.persistent_id.to_s
      end

      def container?(entity)
        entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
      end

      def material_name(entity)
        material = entity.material if entity.respond_to?(:material)
        material ? text(material.name) : nil
      end

      def definition_record(definition)
        key = 'definition_' + id(definition)
        return key if @definitions.key?(key)
        # Register before descending: shared definitions only appear once.
        record = {'id' => key}
        @definitions[key] = record
        attrs = dictionaries(definition)
        record.merge!({
          'persistent_id' => id(definition), 'name' => text(definition.name),
          'description' => text(definition.description),
          'local_bounds_mm' => bounds(definition.bounds),
          'attribute_dictionaries' => attrs, 'dc_formulas' => formulas(attrs),
          'children' => [], 'entity_counts' => {}, 'other_entities_with_attributes' => []
        })
        definition.entities.each do |child|
          type = child.typename
          record['entity_counts'][type] = record['entity_counts'].fetch(type, 0) + 1
          if container?(child)
            record['children'] << instance_record(child)
          else
            child_attrs = dictionaries(child)
            next if child_attrs.empty?
            @attributed_geometry_count += 1
            item = {
              'type' => type, 'persistent_id' => id(child),
              'attribute_dictionaries' => child_attrs, 'dc_formulas' => formulas(child_attrs)
            }
            item['bounds_parent_mm'] = bounds(child.bounds) if child.respond_to?(:bounds)
            record['other_entities_with_attributes'] << item
          end
        end
        key
      end

      def instance_record(entity)
        @container_count += 1
        attrs = dictionaries(entity)
        transform = entity.transformation
        {
          'type' => entity.typename, 'persistent_id' => id(entity),
          'instance_name' => text(entity.name), 'definition_ref' => definition_record(entity.definition),
          'tag' => text(entity.layer.name), 'material_name' => material_name(entity),
          'hidden' => entity.hidden?, 'locked' => entity.locked?,
          'transformation_to_parent' => transform.to_a.map(&:to_f),
          'origin_parent_mm' => mm_point(transform.origin),
          'axis_scale_magnitudes' => [transform.xaxis.length, transform.yaxis.length, transform.zaxis.length].map(&:to_f),
          'mirrored' => transform.xaxis.cross(transform.yaxis).dot(transform.zaxis) < 0,
          'bounds_parent_mm' => bounds(entity.bounds),
          'attribute_dictionaries' => attrs, 'dc_formulas' => formulas(attrs)
        }
      end

      def build(model, selected)
        roots = selected.map { |entity| instance_record(entity) }
        units = {}
        model.options['UnitsOptions'].each_pair { |key, raw| units[text(key)] = value(raw) }
        {
          'schema' => 'tplus.dc_snapshot', 'schema_version' => 1,
          'exporter_version' => VERSION, 'exported_at' => Time.now.iso8601,
          'sketchup_version' => Sketchup.version, 'model_title' => text(model.title),
          'units_options' => units,
          'active_edit_path' => (model.active_path || []).map { |item| {'persistent_id' => id(item), 'name' => text(item.name)} },
          'active_context_to_model' => model.edit_transform.to_a.map(&:to_f),
          'conventions' => {
            'attributes' => 'Stored values from instance and definition remain separate. DC formulas are not evaluated or redrawn.',
            'hierarchy' => 'roots -> definition_ref -> definitions[id].children; shared definitions stored once. Includes hidden and locked children.',
            'coordinates' => 'XYZ follows component axes, not necessarily cabinet W/D/H. Bounds are axis-aligned in the named coordinate frame.',
            'transforms' => 'SketchUp Transformation#to_a, 16 column-major values, translation in inches. Multiply parent transform by child transform.',
            'units' => 'Fields ending _mm are millimetres. Plain attribute numbers/strings retain their original representation; consult DC unit metadata.',
            'scope' => 'All attribute dictionaries of selected containers, reachable definitions and their entities. Geometry is summarized; no mesh or texture files.'
          },
          'summary' => {
            'selected_roots' => roots.length, 'definitions' => @definitions.length,
            'container_records' => @container_count, 'formula_entries' => @formula_count,
            'other_entities_with_attributes' => @attributed_geometry_count
          },
          'roots' => roots, 'definitions' => @definitions, 'warnings' => @warnings.uniq
        }
      end
    end

    def self.export_selected
      model = Sketchup.active_model
      selected = model.selection.to_a.select do |entity|
        entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
      end
      if selected.empty?
        UI.messagebox('Hãy chọn ít nhất một component hoặc group tủ rồi chạy lại công cụ.')
        return
      end
      name = selected.length == 1 ? selected.first.definition.name.to_s : 'Nhieu_component'
      name = name.gsub(/[\\\/:*?"<>|\x00-\x1f]/, '_').strip[0, 70]
      name = 'Component' if name.empty?
      filename = "TPlus_DC_#{name}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
      path = UI.savepanel('T+ DC Exporter — Lưu file JSON', nil, filename)
      return unless path
      path += '.json' unless File.extname(path).downcase == '.json'
      # Complete JSON serialization before touching the output file.
      snapshot = Snapshot.new.build(model, selected)
      json = JSON.pretty_generate(snapshot)
      File.open(path, 'wb') { |file| file.write(json.encode('UTF-8')) }
      summary = snapshot['summary']
      warning = snapshot['warnings'].empty? ? '' : "\nCó lưu ý chuyển đổi kiểu dữ liệu trong mục warnings của JSON."
      UI.messagebox("Đã xuất #{summary['selected_roots']} đối tượng, #{summary['definitions']} định nghĩa và #{summary['formula_entries']} công thức lưu sẵn.\n\n#{path}\n\nGửi file JSON này lại trong cuộc trò chuyện.#{warning}")
      path
    rescue StandardError => error
      puts "[T+ DC Exporter] #{error.class}: #{error.message}\n#{error.backtrace.join("\n")}"
      UI.messagebox("Không xuất được JSON: #{error.message}\nXem Window > Ruby Console để biết chi tiết.")
      nil
    end

    unless file_loaded?(__FILE__)
      UI.menu('Extensions').add_item('T+ DC Exporter — Xuất JSON đối tượng đang chọn') { export_selected }
      file_loaded(__FILE__)
    end
  end
end
