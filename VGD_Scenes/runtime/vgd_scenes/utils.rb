# frozen_string_literal: true
require 'json'
require 'fileutils'
require 'tmpdir'
module VGD
  module Scenes
    DICT = 'VGD.Scenes.v1'.freeze
    DEFAULTS = {
      'project' => '', 'template' => '<OBJECT>_<VIEW>', 'views' => %w[ISO TOP FRONT RIGHT],
      'axis_mode' => 'local', 'grouping' => 'combined', 'isolate' => true,
      'width' => 1920, 'height' => 1080, 'margin' => 10.0,
      'grid' => 'thirds', 'format' => 'png', 'transparent' => false,
      'ratio_locked' => false, 'export_scale' => 1.0, 'date_folder' => false,
      'paper' => 'A4_L', 'section_axis' => 'Y', 'section_percent' => 50.0,
      'section_offset' => 0.0, 'section_flip' => false, 'section_name' => 'A-A',
      'normal_x' => 0.0, 'normal_y' => 1.0, 'normal_z' => 0.0
    }.freeze
    VIEWS = %w[ISO TOP FRONT RIGHT BACK LEFT BOTTOM].freeze

    def self.number(value, min, max, label)
      n = Float(value)
      raise ArgumentError, "#{label}: cần nằm trong #{min}–#{max}" unless n.finite? && n >= min && n <= max
      n
    rescue TypeError, ArgumentError => e
      raise ArgumentError, "#{label}: giá trị không hợp lệ (#{e.message})"
    end

    def self.settings(model)
      stored = JSON.parse(model.get_attribute(DICT, 'settings', '{}')) rescue {}
      DEFAULTS.merge(stored.select { |key, _| DEFAULTS.key?(key) })
    end

    def self.options(raw)
      raise ArgumentError, 'Thông số không hợp lệ' unless raw.is_a?(Hash)
      o = DEFAULTS.merge(raw.select { |key, _| DEFAULTS.key?(key) })
      o['width'] = number(o['width'], 100, 12000, 'Chiều rộng ảnh').round
      o['height'] = number(o['height'], 100, 12000, 'Chiều cao ảnh').round
      raise ArgumentError, 'Ảnh quá lớn: tối đa 64 triệu pixel' if o['width'] * o['height'] > 64_000_000
      o['margin'] = number(o['margin'], 0, 100, 'Lề (%)')
      o['export_scale'] = Float(o['export_scale'])
      raise ArgumentError, 'Scale xuất phải là số hữu hạn lớn hơn 0.' unless o['export_scale'].finite? && o['export_scale'] > 0
      o['section_percent'] = number(o['section_percent'], 0, 100, 'Vị trí cắt (%)')
      o['section_offset'] = number(o['section_offset'], -1_000_000, 1_000_000, 'Dịch mặt cắt (mm)')
      %w[normal_x normal_y normal_z].each { |key| o[key] = number(o[key], -1_000_000, 1_000_000, 'Vector mặt cắt') }
      raise ArgumentError, 'Trục không hợp lệ' unless %w[local world].include?(o['axis_mode'])
      raise ArgumentError, 'Chế độ đối tượng không hợp lệ' unless %w[combined individual].include?(o['grouping'])
      raise ArgumentError, 'Định dạng không hợp lệ' unless %w[png jpg pdf].include?(o['format'])
      raise ArgumentError, 'Khổ giấy không hợp lệ' unless %w[A4_L A4_P A3_L A3_P].include?(o['paper'])
      raise ArgumentError, 'Trục mặt cắt không hợp lệ' unless %w[X Y Z CUSTOM].include?(o['section_axis'])
      raise ArgumentError, 'Loại lưới không hợp lệ' unless %w[none thirds center golden grid4].include?(o['grid'])
      o['views'] = Array(o['views']).uniq
      raise ArgumentError, 'Góc nhìn không hợp lệ' unless (o['views'] - VIEWS).empty?
      %w[isolate transparent section_flip ratio_locked date_folder].each { |key| o[key] = o[key] == true }
      %w[project template section_name].each { |key| o[key] = o[key].to_s.strip[0, 160] }
      raise ArgumentError, 'Mẫu tên không được trống' if o['template'].empty?
      o
    end

    def self.export_dimensions(frame, scale)
      width = frame['width'] * scale; height = frame['height'] * scale
      unless width.finite? && height.finite? && width >= 0.5 && height >= 0.5 && width < 12000.5 && height < 12000.5
        raise ArgumentError, 'Kích thước sau scale phải từ 1–12000 px mỗi chiều.'
      end
      width = width.round; height = height.round
      raise ArgumentError, 'Ảnh sau scale vượt 64 triệu pixel.' if width * height > 64_000_000
      { 'width' => width, 'height' => height }
    end

    def self.output_directory(root, opts, date = Time.now)
      raise ArgumentError, 'Thư mục đích không tồn tại.' unless File.directory?(root)
      destination = opts['date_folder'] ? File.join(root, date.strftime('%Y.%m.%d')) : root
      destination = File.join(destination, opts['format'].upcase)
      FileUtils.mkdir_p(destination)
      destination
    end

    def self.operation(model, label)
      model.start_operation("VGD · #{label}", true)
      begin
        result = yield
        model.commit_operation
        result
      rescue Exception
        model.abort_operation
        raise
      end
    end

    def self.clean_filename(value)
      text = value.to_s.gsub(/[\x00-\x1f<>:"\/\\|?*]/, '_').gsub(/[. ]+\z/, '').strip
      text = 'Scene' if text.empty?
      text = "_#{text}" if text.match?(/\A(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|\z)/i)
      text[0, 100]
    end

    def self.available_path(directory, base, extension)
      stem = clean_filename(base)
      path = File.join(directory, "#{stem}.#{extension}")
      index = 2
      while File.exist?(path)
        path = File.join(directory, "#{stem}_#{index}.#{extension}")
        index += 1
      end
      path
    end

    def self.camera_copy(camera)
      copy = Sketchup::Camera.new(camera.eye, camera.target, camera.up, camera.perspective?)
      copy.aspect_ratio = camera.aspect_ratio
      if camera.perspective?
        copy.fov = camera.fov
      else
        copy.height = camera.height
      end
      copy
    end

    # A scene can change tags, hidden instances, style, shadows and cuts.
    # Restore the user's unsaved view as well as the selected scene.
    class ViewState
      def initialize(model, deep = true)
        @model = model
        @page = model.pages.selected_page
        @camera = Scenes.camera_copy(model.active_view.camera)
        @rendering = []
        model.rendering_options.each { |key, value| @rendering << [key, value] }
        @shadows = %w[DisplayShadows UseSunForAllShading Light Dark ShadowTime TZOffset Latitude Longitude City Country].map { |key| [key, model.shadow_info[key]] }
        @style = model.styles.selected_style
        @layers = model.layers.map { |layer| [layer, layer.visible?] }
        @folders = []
        collect_folders(model.layers.folders) if model.layers.respond_to?(:folders)
        @hidden = []; @sections = []; @visited = {}
        collect_entities(model.entities, deep)
        @selection = model.selection.to_a
        @axes = [model.axes.origin, model.axes.xaxis, model.axes.yaxis, model.axes.zaxis]
      end

      def collect_folders(folders)
        folders.each do |folder|
          @folders << [folder, folder.visible?]
          collect_folders(folder.folders)
        end
      end

      def collect_entities(entities, deep)
        return if @visited[entities.object_id]
        @visited[entities.object_id] = true
        @sections << [entities, entities.active_section_plane]
        entities.each do |entity|
          @hidden << [entity, entity.hidden?] if deep && entity.is_a?(Sketchup::Drawingelement)
          child = entity.is_a?(Sketchup::Group) ? entity.entities : (entity.is_a?(Sketchup::ComponentInstance) ? entity.definition.entities : nil)
          collect_entities(child, deep) if deep && child
        end
      end

      def restore
        return unless @model.valid?
        @model.pages.selected_page = @page if @page && @page.valid? && @model.pages.selected_page != @page
        if @style && @style.valid? && @model.styles.selected_style != @style && @style != @model.styles.active_style
          @model.styles.selected_style = @style
        end
        @rendering.each { |key, value| @model.rendering_options[key] = value if @model.rendering_options[key] != value }
        @shadows.each { |key, value| @model.shadow_info[key] = value if @model.shadow_info[key] != value }
        @layers.each { |layer, visible| layer.visible = visible if layer.valid? && layer.visible? != visible }
        @folders.each { |folder, visible| folder.visible = visible if folder.valid? && folder.visible? != visible }
        @hidden.each { |entity, hidden| entity.hidden = hidden if entity.valid? && entity.hidden? != hidden }
        @sections.each do |entities, plane|
          next if entities.respond_to?(:valid?) && !entities.valid?
          active = entities.active_section_plane
          entities.active_section_plane = (plane && plane.valid? ? plane : nil) if active != plane
        end
        axes = @model.axes
        axes.set(*@axes) if [axes.origin, axes.xaxis, axes.yaxis, axes.zaxis] != @axes
        surviving = @selection.select(&:valid?)
        unless @model.selection.to_a == surviving
          @model.selection.clear
          @model.selection.add(surviving)
        end
        @model.active_view.camera = @camera
        @model.active_view.invalidate
      end
    end
  end
end
