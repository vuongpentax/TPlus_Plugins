# frozen_string_literal: true
require 'securerandom'
module VGD
  module Scenes
    # Portable data only. Entity IDs, source paths, cuts and other extensions'
    # dictionaries intentionally never enter a transfer bundle.
    module SceneTransfer
      FORMAT = 'VGD.Scenes.Transfer'.freeze
      MAX_BYTES = 8 * 1024 * 1024
      MAX_SCENES = 1000

      def self.guard(model)
        raise 'Đóng edit Group/Component trước khi chuyển scene.' if model.active_path
      end

      def self.two_point?(camera)
        camera.respond_to?(:is_2d?) && camera.is_2d?
      end

      def self.camera_data(camera)
        raise 'Chưa hỗ trợ phối cảnh hai điểm / Match Photo. Đổi sang Perspective hoặc Parallel Projection rồi lưu scene.' if two_point?(camera)
        data = { 'eye' => camera.eye.to_a, 'target' => camera.target.to_a, 'up' => camera.up.to_a,
                 'perspective' => camera.perspective?, 'aspect' => camera.aspect_ratio }
        if camera.perspective?
          data['fov'] = camera.fov
          data['fov_vertical'] = camera.fov_is_height?
        else
          data['height'] = camera.height # SketchUp API coordinates are inches.
        end
        data
      end

      def self.number(value, label, min = nil, max = nil)
        raise ArgumentError, "#{label}: cần số hữu hạn." unless value.is_a?(Numeric) && value.to_f.finite?
        value = value.to_f
        raise ArgumentError, "#{label}: ngoài giới hạn." if (min && value < min) || (max && value > max)
        value
      end

      def self.vector(value, label)
        raise ArgumentError, "#{label}: cần 3 tọa độ." unless value.is_a?(Array) && value.length == 3
        value.map { |v| number(v, label, -1e12, 1e12) }
      end

      def self.text(value, label, limit)
        raise ArgumentError, "#{label}: không hợp lệ." unless value.is_a?(String) && value.valid_encoding? && value.length <= limit && !value.match?(/[\x00-\x1f]/)
        value
      end

      def self.validate_camera(raw)
        raise ArgumentError, 'Thiếu dữ liệu camera.' unless raw.is_a?(Hash)
        eye = Geom::Point3d.new(vector(raw['eye'], 'Eye'))
        target = Geom::Point3d.new(vector(raw['target'], 'Target'))
        up = Geom::Vector3d.new(vector(raw['up'], 'Up'))
        direction = target - eye
        raise ArgumentError, 'Camera có hướng nhìn không hợp lệ.' if direction.length < 1e-9 || up.length < 1e-9 || direction.normalize.cross(up.normalize).length < 1e-9
        raise ArgumentError, 'Kiểu camera không hợp lệ.' unless [true, false].include?(raw['perspective'])
        number(raw['aspect'], 'Tỷ lệ camera', 0, 120)
        if raw['perspective']
          raise ArgumentError, 'Thiếu hướng FOV.' unless [true, false].include?(raw['fov_vertical'])
          Scenes.valid_fov(raw['fov'])
        else
          number(raw['height'], 'Chiều cao camera', 1e-9, 1e12)
        end
        raw
      end

      def self.camera(raw)
        validate_camera(raw)
        result = Sketchup::Camera.new(Geom::Point3d.new(raw['eye']), Geom::Point3d.new(raw['target']), Geom::Vector3d.new(raw['up']), raw['perspective'])
        result.aspect_ratio = raw['aspect']
        if raw['perspective']
          fov = Scenes.convert_fov(raw['fov'], raw['fov_vertical'], result.fov_is_height?, result.aspect_ratio)
          Scenes.set_camera_fov(result, fov)
        else
          result.height = raw['height']
        end
        result
      end

      def self.validate(raw)
        raise ArgumentError, 'Không phải bộ scene VGD phiên bản 1.' unless raw.is_a?(Hash) && raw['format'] == FORMAT && raw['version'] == 1
        entries = raw['scenes']
        raise ArgumentError, "Bộ scene cần có 1–#{MAX_SCENES} scene." unless entries.is_a?(Array) && entries.length.between?(1, MAX_SCENES)
        seen = {}
        entries.each do |entry|
          raise ArgumentError, 'Scene không hợp lệ.' unless entry.is_a?(Hash)
          id = entry['id']
          raise ArgumentError, 'ID chuyển scene không hợp lệ hoặc bị trùng.' unless id.is_a?(String) && id.match?(/\A[0-9a-f]{32}\z/) && !seen[id]
          seen[id] = true
          name = text(entry['name'], 'Tên scene', 180)
          raise ArgumentError, 'Tên scene không được trống.' if name.strip.empty?
          # Export/reading validates data without constructing a native camera.
          # Import still constructs EVERY selected camera before any writes.
          validate_camera(entry['camera'])
          frame = entry['frame']
          raise ArgumentError, 'Khung scene không hợp lệ.' unless frame.is_a?(Hash) && SceneFrame::KEYS.all? { |k| frame.key?(k) }
          SceneFrame::KEYS.each { |k| number(frame[k], "Khung #{k}") }
          Scenes.options(frame)
        rescue StandardError => error
          label = entry.is_a?(Hash) && entry['name'].is_a?(String) ? entry['name'] : 'Scene'
          raise ArgumentError, "#{label}: #{error.message}"
        end
        text(raw.fetch('title', ''), 'Tên model', 300)
        raw
      end

      def self.bundle(model, ids = nil)
        guard(model)
        ids = Array(ids).map(&:to_s).uniq unless ids.nil?
        ordered = SceneStore.ordered(model)
        pages = ids.nil? ? ordered : ordered.select { |p| ids.include?(p.persistent_id.to_s) }
        raise ArgumentError, 'Danh sách scene đã đổi. Chọn lại scene.' if ids && pages.length != ids.length
        raise ArgumentError, 'Chọn scene cần copy/xuất.' if pages.empty?
        used_ids = {}
        entries = pages.map do |page|
          raise ArgumentError, "#{page.name}: scene chưa lưu camera." unless page.use_camera?
          id = page.get_attribute(DICT, 'transfer_id')
          id = SecureRandom.hex(16) unless id.is_a?(String) && id.match?(/\A[0-9a-f]{32}\z/) && !used_ids[id]
          used_ids[id] = true
          frame = SceneFrame.read(page, Scenes.settings(model))
          data = camera_data(page.camera)
          # Freeze the output frame for cameras that otherwise depend on the
          # receiving SketchUp window size. This makes image export portable.
          data['aspect'] = frame['width'].to_f / frame['height'] if data['aspect'] == 0
          { 'id' => id, 'name' => page.name, 'camera' => data, 'frame' => frame }
        rescue StandardError => e
          raise ArgumentError, "#{page.name}: #{e.message}"
        end
        raw = validate('format' => FORMAT, 'version' => 1, 'title' => model.title.to_s[0, 300], 'scenes' => entries)
        raise ArgumentError, 'Bộ scene vượt 8 MB.' if JSON.generate(raw).bytesize > MAX_BYTES
        # Stable IDs survive source renames and saving an SKP to a new path.
        changes = pages.zip(entries).reject { |p, e| p.get_attribute(DICT, 'transfer_id') == e['id'] }
        unless changes.empty?
          Scenes.operation(model, 'Gán ID chuyển scene VGD') do
            changes.each { |page, entry| page.set_attribute(DICT, 'transfer_id', entry['id']) }
          end
        end
        raw
      end

      def self.clipboard_path
        root = ENV['APPDATA']
        root = File.join(Dir.home, '.config') if root.nil? || root.empty?
        File.join(root, 'VGD', 'Scenes', 'scene_clipboard_v1.json')
      end

      def self.write(path, raw, replace = false)
        data = JSON.pretty_generate(validate(raw))
        raise ArgumentError, 'Bộ scene vượt 8 MB.' if data.bytesize > MAX_BYTES
        raise ArgumentError, 'Tệp đích đã tồn tại.' if !replace && File.exist?(path)
        temporary = "#{path}.#{SecureRandom.hex(8)}.tmp"
        begin
          File.open(temporary, 'wb', 0600) { |file| file.write(data); file.flush }
          # Only the private VGD clipboard is replaced. Export uses exclusive
          # creation so an existing user file cannot be overwritten in a race.
          if replace
            File.rename(temporary, path)
          else
            File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0600) { |file| file.write(data) }
          end
        ensure
          File.delete(temporary) if File.file?(temporary)
        end
        path
      end

      def self.read(path)
        raise ArgumentError, 'Chưa có bộ scene để paste. Copy trong file A trước.' unless File.file?(path)
        raise ArgumentError, 'Bộ scene vượt 8 MB.' if File.size(path) > MAX_BYTES
        data = File.binread(path, MAX_BYTES + 1)
        raise ArgumentError, 'Bộ scene vượt 8 MB.' if data.bytesize > MAX_BYTES
        validate(JSON.parse(data.force_encoding(Encoding::UTF_8), max_nesting: 32))
      rescue JSON::ParserError, EncodingError
        raise ArgumentError, 'Tệp JSON không hợp lệ. Hãy xuất lại bộ scene từ VGD.'
      end

      def self.index(model)
        lookup = { ids: Hash.new { |h, k| h[k] = [] }, names: Hash.new { |h, k| h[k] = [] } }
        model.pages.each do |page|
          lookup[:names][page.name] << page
          [page.get_attribute(DICT, 'transfer_id'), page.get_attribute(DICT, 'transfer_origin')].compact.uniq.each do |id|
            lookup[:ids][id] << page
          end
        end
        lookup
      end

      def self.match(model, entry, lookup = nil)
        lookup ||= index(model)
        by_id = lookup[:ids][entry['id']]
        candidates = by_id.empty? ? lookup[:names][entry['name']] : by_id
        return candidates.first if candidates.length <= 1
        exact = candidates.select { |p| p.name == entry['name'] }
        return exact.first if exact.length == 1
        raise ArgumentError, "#{entry['name']}: nhiều scene trùng ID/tên. Đổi tên hoặc chọn Tạo mới."
      end

      def self.preview(model, raw, token)
        lookup = index(model)
        { token: token, title: raw['title'], scenes: raw['scenes'].map do |entry|
          matched = match(model, entry, lookup)
          { id: entry['id'], name: entry['name'], match: matched && matched.name, target_id: matched && matched.persistent_id.to_s }
        rescue ArgumentError
          { id: entry['id'], name: entry['name'], ambiguous: true }
        end }
      end

      def self.set_camera(destination, source)
        destination.set(source.eye, source.target, source.up)
        destination.perspective = source.perspective?
        destination.aspect_ratio = source.aspect_ratio
        Scenes.copy_camera_lens(destination, source)
      end

      def self.restore_camera(destination, data, view = nil)
        destination.set(Geom::Point3d.new(data['eye']), Geom::Point3d.new(data['target']), Geom::Vector3d.new(data['up']))
        destination.perspective = data['perspective']
        destination.aspect_ratio = data['aspect']
        if data['perspective']
          aspect = data['aspect']
          if aspect <= 0 && data['fov_vertical'] != destination.fov_is_height?
            view ||= Sketchup.active_model.active_view
            aspect = view.vpwidth.to_f / view.vpheight
          end
          Scenes.set_camera_fov(destination, Scenes.convert_fov(data['fov'], data['fov_vertical'], destination.fov_is_height?, aspect))
        else
          destination.height = data['height']
        end
      end

      def self.restore_attribute(page, key, value)
        value.nil? ? page.delete_attribute(DICT, key) : page.set_attribute(DICT, key, value)
      end

      def self.apply(model, raw, ids, mode, expected = nil)
        guard(model)
        validate(raw)
        raise ArgumentError, 'Chế độ nhập scene không hợp lệ.' unless %w[new update skip].include?(mode)
        ids = Array(ids).map(&:to_s).uniq
        entries = raw['scenes'].select { |e| ids.include?(e['id']) }
        raise ArgumentError, 'Chọn ít nhất một scene hợp lệ để nhập.' if entries.empty? || entries.length != ids.length
        lookup = index(model)
        plans = entries.map do |entry|
          target = mode == 'new' ? nil : match(model, entry, lookup)
          if mode != 'new' && expected && expected[entry['id']] != (target && target.persistent_id.to_s)
            raise ArgumentError, 'Scene đích đã đổi sau khi xem trước. Paste/Nhập lại để kiểm tra.'
          end
          if target && mode == 'update' && two_point?(target.camera)
            raise ArgumentError, "#{target.name}: camera đích đang là hai điểm / Match Photo. Chọn Tạo mới."
          end
          [entry, target, camera(entry['camera'])]
        rescue StandardError => error
          raise ArgumentError, "#{entry['name']}: #{error.message}"
        end
        targets = plans.select { |_e, p, _c| p && mode == 'update' }.map { |_e, p, _c| p }
        raise ArgumentError, 'Nhiều scene nguồn cùng khớp một scene đích. Chọn Tạo mới hoặc nhập riêng.' unless targets.uniq.length == targets.length
        original_camera = model.active_view.camera
        original_page = model.pages.selected_page
        # Direct Page#camera edits keep the target's cuts/style/visibility.
        # Explicit rollback is also needed on SU22–25 where scene-camera edits
        # do not participate in the native Undo operation.
        backups = targets.map do |page|
          [page, camera_data(page.camera), page.use_camera?,
           %w[frame transfer_origin camera_custom].map { |key| [key, page.get_attribute(DICT, key)] }]
        end
        created = []; affected = []; updated = 0; skipped = 0
        Scenes.operation(model, 'Nhập góc scene VGD') do
          begin
            plans.each do |entry, page, new_camera|
              if page && mode == 'skip'
                skipped += 1; next
              end
              if page
                set_camera(page.camera, new_camera)
                page.use_camera = true
                page.set_attribute(DICT, 'transfer_origin', entry['id'])
                page.set_attribute(DICT, 'camera_custom', true) if SceneStore.owned?(page)
                updated += 1
              else
                model.active_view.camera = new_camera
                page = model.pages.add(SceneStore.unique_name(model, entry['name']), PAGE_USE_CAMERA)
                raise 'SketchUp không tạo được scene.' unless page && page.valid?
                created << page
                page.use_camera = true
                page.set_attribute(DICT, 'transfer_id', SecureRandom.hex(16))
                page.set_attribute(DICT, 'transfer_origin', entry['id'])
              end
              SceneFrame.store(page, entry['frame'])
              affected << page.persistent_id.to_s
            end
          rescue StandardError => error
            failures = []
            created.reverse_each do |page|
              model.pages.erase(page) if page.valid?
            rescue StandardError => rollback_error
              failures << rollback_error.message
            end
            backups.each do |page, saved_camera, use_camera, attributes|
              restore_camera(page.camera, saved_camera, model.active_view)
              page.use_camera = use_camera
              attributes.each { |key, value| restore_attribute(page, key, value) }
            rescue StandardError => rollback_error
              failures << rollback_error.message
            end
            raise "#{error.message}\nKhông phục hồi hết: #{failures.join('; ')}" unless failures.empty?
            raise error
          ensure
            model.pages.selected_page = original_page if original_page && original_page.valid? && model.pages.selected_page != original_page
            model.active_view.camera = original_camera
            model.active_view.invalidate
          end
        end
        { success: true, ids: affected, message: "Đã nhập: #{created.length} mới, #{updated} cập nhật, #{skipped} bỏ qua. Chỉ camera và khung hình." }
      end
    end
  end
end
