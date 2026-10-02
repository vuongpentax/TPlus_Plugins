# frozen_string_literal: true
module VGD
  module Scenes
    module SceneStore
      def self.owned?(page)
        page.get_attribute(DICT, 'owner') == 'VGD Scenes'
      end

      def self.metadata(page)
        JSON.parse(page.get_attribute(DICT, 'source', '{}'))
      end

      def self.find(model, id)
        page = model.pages.find { |p| p.persistent_id.to_s == id.to_s }
        raise ArgumentError, 'Scene không còn tồn tại. Làm mới danh sách.' unless page
        page
      end

      def self.list(model)
        model.pages.map do |page|
          source = owned?(page) ? metadata(page) : {}
          { id: page.persistent_id.to_s, name: page.name, owned: owned?(page),
            kind: source['kind'], selected: page == model.pages.selected_page }
        end
      end

      def self.name(options, target, kind, index)
        values = { 'PROJECT' => options['project'], 'OBJECT' => target[:name], 'VIEW' => kind, 'INDEX' => format('%02d', index) }
        text = options['template'].gsub(/<([A-Z]+)>|\{([A-Z]+)\}/i) { |token| values[($1 || $2).upcase] || token }
        text = text.gsub(/[\x00-\x1f]/, ' ').strip[0, 180]
        raise ArgumentError, 'Tên scene rỗng sau khi áp dụng mẫu.' if text.empty?
        text
      end

      def self.unique_name(model, proposed, except = nil)
        text = proposed
        index = 2
        while model.pages.any? { |page| page != except && page.name == text }
          text = "#{proposed} (#{index})"; index += 1
        end
        text
      end

      def self.prepare_page(page)
        page.use_camera = true
        page.use_rendering_options = true
        page.use_style = false
        page.use_hidden_geometry = true
        page.use_hidden_objects = true
        page.use_hidden_layers = true
        page.use_section_planes = true
      end

      def self.flags
        PAGE_USE_CAMERA | PAGE_USE_RENDERING_OPTIONS | PAGE_USE_HIDDEN_GEOMETRY |
          PAGE_USE_HIDDEN_OBJECTS | PAGE_USE_LAYER_VISIBILITY | PAGE_USE_SECTION_PLANES
      end

      def self.isolate(page, model, target)
        keep = target[:resolved].flat_map { |path, _t, _entities| path }
        model.entities.each do |entity|
          next unless entity.is_a?(Sketchup::Drawingelement)
          page.set_drawingelement_visibility(entity, keep.include?(entity))
        end
        # Nested instance siblings are page overrides only; definitions are never edited.
        target[:resolved].each do |path, _t, _entities|
          path.each_with_index do |parent, index|
            next if index == path.length - 1
            parent.definition.entities.each do |sibling|
              next unless Geometry.instance?(sibling) || sibling.is_a?(Sketchup::Image)
              page.set_drawingelement_visibility(sibling, keep.include?(sibling))
            end
          end
        end
        keep.each do |entity|
          page.set_drawingelement_visibility(entity, true)
          page.set_visibility(entity.layer, true)
          folder = entity.layer.respond_to?(:folder) ? entity.layer.folder : nil
          while folder
            page.set_visibility(folder, true)
            folder = folder.respond_to?(:folder) ? folder.folder : nil
          end
        end
      end

      def self.plane_for(model, page)
        model.entities.find { |e| e.is_a?(Sketchup::SectionPlane) && e.get_attribute(DICT, 'scene_pid').to_s == page.persistent_id.to_s && e.get_attribute(DICT, 'owner') == 'VGD Scenes' }
      end

      def self.write(model, page, target, kind, opts)
        normal = nil
        plane = nil
        if kind == 'SECTION'
          point, normal = Geometry.section(target, opts)
          plane = plane_for(model, page)
          if plane
            plane.set_plane([point, normal])
          else
            plane = model.entities.add_section_plane([point, normal])
            raise 'SketchUp không tạo được mặt cắt.' unless plane
            plane.layer = model.layers[0]
            plane.set_attribute(DICT, 'owner', 'VGD Scenes')
            plane.set_attribute(DICT, 'scene_pid', page.persistent_id.to_s)
          end
          plane.name = "VGD · #{opts['section_name']}"
          plane.hidden = true
        end
        # The cut is selected BEFORE the page is captured.
        model.entities.active_section_plane = plane
        model.rendering_options['DisplaySectionCuts'] = !plane.nil?
        model.rendering_options['DisplaySectionPlanes'] = false
        Geometry.fit(model, target, kind, opts, normal)
        prepare_page(page)
        raise 'SketchUp không lưu được trạng thái scene.' unless page.update(flags)
        isolate(page, model, target) if opts['isolate']
        page.set_attribute(DICT, 'owner', 'VGD Scenes')
        page.set_attribute(DICT, 'source', { 'paths' => target[:paths], 'kind' => kind, 'options' => opts }.to_json)
        page
      end

      def self.generate(model, raw, section_only = false)
        opts = Scenes.options(raw)
        kinds = section_only ? ['SECTION'] : opts['views']
        raise ArgumentError, 'Chọn ít nhất một góc nhìn.' if kinds.empty?
        paths = Geometry.selection_paths(model)
        sets = opts['grouping'] == 'individual' ? paths.map { |path| [path] } : [paths]
        raise ArgumentError, 'Tối đa 100 scene mỗi lượt. Giảm đối tượng hoặc góc nhìn.' if sets.length * kinds.length > 100
        targets = sets.map { |set| Geometry.target(model, set, opts['axis_mode']) }
        targets.each { |target| Geometry.section(target, opts) } if section_only
        snapshot = ViewState.new(model, false)
        generated = []
        Scenes.operation(model, section_only ? 'Tạo mặt cắt' : 'Tạo góc nhìn') do
          begin
            targets.each do |target|
              kinds.each do |kind|
                existing = model.pages.find do |page|
                  next false unless owned?(page)
                  source = metadata(page)
                  source['paths'] == target[:paths] && source['kind'] == kind &&
                    (kind != 'SECTION' || source.dig('options', 'section_name') == opts['section_name'])
                end
                label_kind = kind == 'SECTION' ? "SEC_#{opts['section_name']}" : kind
                page = existing || model.pages.add(unique_name(model, name(opts, target, label_kind, generated.length + 1)))
                write(model, page, target, kind, opts)
                generated << page
              end
            end
            model.set_attribute(DICT, 'settings', opts.to_json)
          ensure
            snapshot.restore
          end
        end
        model.pages.selected_page = generated.first unless model.active_path
        { success: true, message: "Đã tạo/cập nhật #{generated.length} scene.", ids: generated.map { |p| p.persistent_id.to_s } }
      end

      def self.update_sources(model, ids)
        pages = Array(ids).map { |id| find(model, id) }
        raise ArgumentError, 'Chọn scene VGD cần cập nhật.' if pages.empty?
        raise ArgumentError, 'Cập nhật từ nguồn chỉ áp dụng scene VGD. Scene khác dùng nút lưu góc nhìn.' unless pages.all? { |p| owned?(p) }
        plans = pages.map do |page|
          data = metadata(page); opts = Scenes.options(data.fetch('options'))
          target = Geometry.target(model, data.fetch('paths'), opts['axis_mode'])
          [page, target, data.fetch('kind'), opts]
        end
        snapshot = ViewState.new(model, false)
        Scenes.operation(model, 'Cập nhật từ đối tượng') do
          begin
            plans.each { |page, target, kind, opts| write(model, page, target, kind, opts) }
          ensure
            snapshot.restore
          end
        end
        { success: true, message: "Đã cập nhật #{pages.length} scene theo đối tượng nguồn." }
      end

      def self.rename(model, id, raw_name)
        page = find(model, id)
        label = raw_name.to_s.gsub(/[\x00-\x1f]/, ' ').strip[0, 180]
        raise ArgumentError, 'Tên scene không được trống.' if label.empty?
        raise ArgumentError, 'Tên scene đã tồn tại.' if model.pages.any? { |p| p != page && p.name == label }
        Scenes.operation(model, 'Đổi tên scene') { page.name = label }
        { success: true, message: "Đã đổi tên: #{label}" }
      end

      def self.capture(model, id)
        page = find(model, id)
        Scenes.operation(model, 'Lưu góc nhìn vào scene') do
          page.use_camera = true
          page.use_rendering_options = true
          page.use_hidden_geometry = true
          page.use_hidden_objects = true
          page.use_hidden_layers = true
          page.use_section_planes = true
          raise 'Không lưu được scene.' unless page.update(flags)
          # Refit-from-source would overwrite a manually composed camera.
          page.set_attribute(DICT, 'camera_custom', true) if owned?(page)
        end
        { success: true, message: "Đã lưu góc nhìn hiện tại vào #{page.name}." }
      end

      def self.delete(model, ids)
        pages = Array(ids).uniq.map { |id| find(model, id) }
        raise ArgumentError, 'Chọn scene cần xóa.' if pages.empty?
        Scenes.operation(model, 'Xóa scene đã chọn') do
          pages.each do |page|
            # Keep a plane if another scene refers to it; never erase foreign planes.
            plane = owned?(page) ? plane_for(model, page) : nil
            model.pages.erase(page)
            if plane && plane.valid?
              # Other pages can capture the same native section: retain geometry conservatively.
              plane.set_attribute(DICT, 'orphan', true)
            end
          end
        end
        { success: true, message: "Đã xóa #{pages.length} scene. Có thể Undo." }
      end
    end
  end
end
