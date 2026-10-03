# frozen_string_literal: true
require 'sketchup.rb'
require 'uri'
require_relative 'utils'
require_relative 'geometry'
require_relative 'scenes'
require_relative 'frame'
require_relative 'export'
require_relative 'transfer'
require_relative 'camera'
module VGD
  module Scenes
    VERSION = '1.2.2'.freeze unless const_defined?(:VERSION, false)
    class << self
      def state
        model = Sketchup.active_model
        { model: model.object_id.to_s, title: model.title.empty? ? 'Model chưa lưu' : model.title,
          selection: model.selection.count { |e| Geometry.instance?(e) }, editing: !model.active_path.nil?,
          scenes: SceneStore.list(model), settings: settings(model), camera: CameraControl.state(model), frame_cleanup: SceneFrame.cleanup_state(model),
          current_frame: model.pages.selected_page ? SceneFrame.read(model.pages.selected_page, settings(model)) : SceneFrame.from_camera(model.active_view.camera, settings(model)),
          frame_active: model.active_view.camera.aspect_ratio > 0, grid_active: FrameTool.active?, busy: !@job.nil?,
          transfer: @transfer_pending && @transfer_pending[:model].equal?(model) ? @transfer_pending[:preview] : nil }
      end

      def send_event(event, data)
        return unless @dialog && @dialog.visible?
        @dialog.execute_script("window.VGDScenes && window.VGDScenes.receive(#{event.to_json}, #{data.to_json});")
      rescue StandardError => e
        puts "[VGD Scenes] Dialog: #{e.message}"
      end

      def sync_frame
        send_event('frame', { frame_active: Sketchup.active_model.active_view.camera.aspect_ratio > 0, grid_active: FrameTool.active? })
      end

      def checked_model(data)
        model = Sketchup.active_model
        raise ArgumentError, 'Model đã đổi. Làm mới trước khi thao tác.' unless data['model'].to_s == model.object_id.to_s
        model
      end

      def dispatch(action, data)
        raise ArgumentError, 'Dữ liệu giao diện không hợp lệ.' unless data.is_a?(Hash)
        model = checked_model(data)
        raise 'Đang xuất. Hủy hoặc chờ hoàn tất trước khi đổi scene.' if @job && !%w[cancel refresh].include?(action)
        result = case action
                 when 'refresh' then nil
                 when 'generate' then SceneStore.generate(model, data.fetch('settings'))
                 when 'section' then SceneStore.generate(model, data.fetch('settings'), true)
                 when 'rename' then SceneStore.rename(model, data['id'], data['name'])
                 when 'capture' then SceneStore.capture(model, data['id'])
                 when 'update' then SceneStore.update_sources(model, data['ids'])
                 when 'delete' then SceneStore.delete(model, data['ids'])
                 when 'reorder' then SceneStore.reorder(model, data['id'], data['before'], data['order'])
                 when 'cameraElevation' then CameraControl.elevation(model, data['camera'])
                 when 'removeAllFrames' then SceneFrame.cleanup(model)
                 when 'restoreAllFrames' then SceneFrame.cleanup(model, true)
                 when 'copyScenes', 'saveScenes' then transfer_export(model, data, action == 'copyScenes')
                 when 'pasteScenes', 'loadScenes' then transfer_load(model, action == 'pasteScenes')
                 when 'cancelTransfer'
                   @transfer_pending = nil
                   { success: true, cancelled: true, message: 'Đã hủy nhập scene.' }
                 when 'applyTransfer'
                   pending = @transfer_pending
                   raise 'Bộ scene đã đổi hoặc model đã đổi. Paste/Nhập lại.' unless pending && pending[:model].equal?(model) && pending[:token] == data['token']
                   expected = pending[:preview][:scenes].each_with_object({}) { |entry, hash| hash[entry[:id]] = entry[:target_id] }
                   result = SceneTransfer.apply(model, pending[:data], data['ids'], data['mode'], expected)
                   @transfer_pending = nil
                   result
                 when 'visit'
                   raise 'Đóng edit Group/Component trước khi mở scene.' if model.active_path
                   model.pages.selected_page = SceneStore.find(model, data['id'])
                   { success: true, message: 'Đã mở scene.' }
                 when 'frame', 'fit', 'preview', 'toggle_frame', 'grid'
                   opts = options(data.fetch('settings'))
                   if action == 'grid'
                     FrameTool.toggle(model, opts)
                     { success: true, message: FrameTool.active? ? 'Đã bật lưới. Dùng chuột giữa để Orbit; Esc để tắt lưới.' : 'Đã tắt lưới; khung canh view giữ nguyên.' }
                   elsif action == 'toggle_frame'
                     toggle_frame(model, opts)
                   else
                     apply_frame(model, opts, action == 'fit', action == 'frame')
                   end
                 when 'cancel'
                   @job.cancel if @job
                   { success: true, message: 'Đang hủy sau ảnh hiện tại…' }
                 when 'openOutput'
                   raise 'Chưa có thư mục kết quả từ lượt xuất này.' unless @output_folder && File.directory?(@output_folder)
                   ::UI.openURL('file:///' + URI::DEFAULT_PARSER.escape(@output_folder.tr('\\', '/')))
                   nil
                 when 'export'
                   export_selected(model, data)
                   nil
                 else raise ArgumentError, 'Lệnh không được hỗ trợ.'
                 end
        send_event('result', result) if result
        send_event('state', state)
        result
      rescue StandardError => e
        puts "[VGD Scenes] #{action}: #{e.message}\n#{Array(e.backtrace).first(5).join("\n")}"
        send_event('result', { success: false, message: e.message })
        send_event('state', state)
        { success: false, message: e.message }
      end

      def export_selected(model, data)
        opts = options(data.fetch('settings'))
        ids = Array(data['ids']).uniq
        raise ArgumentError, 'Đánh dấu ít nhất một scene để xuất.' if ids.empty?
        raise ArgumentError, 'Đóng chế độ edit Group/Component trước khi xuất.' if model.active_path
        # VGD order is independent of native scene tabs and checkbox click order.
        pages = SceneStore.ordered(model).select { |p| ids.include?(p.persistent_id.to_s) }
        raise ArgumentError, 'Danh sách scene đã thay đổi. Làm mới và chọn lại.' unless pages.length == ids.length
        pages.each do |page|
          export_dimensions(SceneFrame.read(page, opts), opts['export_scale'])
        rescue StandardError => e
          raise ArgumentError, "#{page.name}: #{e.message}"
        end
        destination = if opts['format'] == 'pdf'
                        ::UI.savepanel('VGD · Lưu PDF nhiều trang', '', "#{clean_filename(opts['project'].empty? ? 'VGD_Scenes' : opts['project'])}.pdf")
                      else
                        ::UI.select_directory(title: 'VGD · Chọn thư mục xuất ảnh')
                      end
        unless destination
          send_event('result', { success: false, cancelled: true, message: 'Đã hủy chọn nơi lưu.' })
          return
        end
        raise ArgumentError, 'Thư mục đích không tồn tại.' unless File.directory?(opts['format'] == 'pdf' ? File.dirname(destination) : destination)
        if opts['format'] == 'pdf'
          directory = output_directory(File.dirname(destination), opts)
          filename = File.basename(destination).sub(/\.pdf\z/i, '')
          destination = available_path(directory, filename, 'pdf')
        else
          destination = output_directory(destination, opts)
        end
        @job = ExportJob.new(model, pages, opts, destination, lambda do |event, result|
          @job = nil if event == :complete
          @output_folder = opts['format'] == 'pdf' ? File.dirname(result[:path]) : result[:path] if event == :complete && result[:path]
          send_event(event == :complete ? 'exported' : 'progress', result)
          send_event('state', state) if event == :complete
        end)
        send_event('started', { total: pages.length })
        @job.start
      end

      def transfer_export(model, data, clipboard)
        SceneTransfer.guard(model)
        ids = Array(data['ids']).map(&:to_s)
        if clipboard && ids.empty?
          page = model.pages.selected_page
          raise 'Chọn scene cần copy trước. Lưu view nếu vừa chỉnh camera.' unless page && page.valid?
          ids = [page.persistent_id.to_s]
        end
        ids = nil if !clipboard && data['scope'] == 'all'
        destination = clipboard ? SceneTransfer.clipboard_path : ::UI.savepanel('VGD · Xuất bộ góc scene', '', 'VGD_Scenes.vgdscenes.json')
        return { success: false, cancelled: true, message: 'Đã hủy chọn tệp.' } unless destination
        unless clipboard
          destination += '.vgdscenes.json' unless destination.downcase.end_with?('.vgdscenes.json')
          destination = available_path(File.dirname(destination), File.basename(destination, '.vgdscenes.json'), 'vgdscenes.json')
        end
        bundle = SceneTransfer.bundle(model, ids)
        FileUtils.mkdir_p(File.dirname(destination)) if clipboard
        SceneTransfer.write(destination, bundle, clipboard)
        { success: true, message: clipboard ? "Đã copy #{bundle['scenes'].length} scene đã lưu. Mở file B và Paste scenes." : "Đã xuất #{bundle['scenes'].length} scene: #{destination}" }
      end

      def transfer_load(model, clipboard)
        SceneTransfer.guard(model)
        source = clipboard ? SceneTransfer.clipboard_path : ::UI.openpanel('VGD · Nhập bộ góc scene', '', 'JSON|*.vgdscenes.json;*.json||')
        return { success: false, cancelled: true, message: 'Đã hủy chọn tệp.' } unless source
        bundle = SceneTransfer.read(source)
        token = SecureRandom.hex(16)
        @transfer_pending = { model: model, data: bundle, token: token, preview: SceneTransfer.preview(model, bundle, token) }
        { success: true, message: "Chọn scene và cách xử lý trùng trước khi nhập #{bundle['scenes'].length} góc nhìn." }
      end

      def transfer_command(action)
        raise 'Đang xuất, hãy chờ hoàn tất.' if @job
        result = case action
                 when 'copyScenes' then transfer_export(Sketchup.active_model, { 'ids' => [] }, true)
                 when 'saveScenes' then transfer_export(Sketchup.active_model, { 'scope' => 'all' }, false)
                 else transfer_load(Sketchup.active_model, action == 'pasteScenes')
                 end
        open if @transfer_pending && %w[pasteScenes loadScenes].include?(action)
        Sketchup.status_text = "[VGD] #{result[:message]}"
        send_event('result', result)
        send_event('state', state)
        result
      rescue StandardError => e
        ::UI.messagebox("VGD Scenes\n#{e.message}")
        { success: false, message: e.message }
      end

      def open
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          send_event('state', state)
          return
        end
        @dialog = ::UI::HtmlDialog.new(dialog_title: "VGD Scenes · #{VERSION}", preferences_key: 'VGD.Scenes.Dialog.v1',
          scrollable: false, resizable: true, width: 640, height: 780, min_width: 460, min_height: 540,
          style: ::UI::HtmlDialog::STYLE_DIALOG)
        @dialog.set_file(File.join(__dir__, 'dialog.html'))
        @dialog.add_action_callback('ready') { |_context, _payload| send_event('state', state) }
        @dialog.add_action_callback('action') do |_context, payload|
          begin
            data = JSON.parse(payload)
            dispatch(data.fetch('action'), data)
          rescue StandardError => e
            send_event('result', { success: false, message: "Dữ liệu không hợp lệ: #{e.message}" })
          end
        end
        @dialog.set_on_closed { @dialog = nil; @transfer_pending = nil; @job.cancel if @job }
        @dialog.show
      end

      def quick_views
        raise 'Đang xuất, hãy chờ hoàn tất.' if @job
        model = Sketchup.active_model
        result = SceneStore.generate(model, settings(model).merge('views' => %w[ISO TOP FRONT RIGHT]))
        send_event('state', state)
        Sketchup.status_text = "[VGD] #{result[:message]}"
      rescue StandardError => e
        ::UI.messagebox("VGD Scenes\n#{e.message}")
      end

      def capture_current_view
        raise 'Đang xuất, hãy chờ hoàn tất trước khi cập nhật scene.' if @job
        model = Sketchup.active_model
        raise 'Đóng edit Group/Component trước khi cập nhật view.' if model.active_path
        page = model.pages.selected_page
        raise 'Chọn một scene trước, chỉnh góc nhìn rồi bấm Cập nhật view hiện tại.' unless page && page.valid?
        result = SceneStore.capture(model, page.persistent_id.to_s)
        Sketchup.status_text = "[VGD] #{result[:message]}"
        send_event('result', result)
        send_event('state', state)
        result
      rescue StandardError => e
        ::UI.messagebox("VGD Scenes\n#{e.message}")
        { success: false, message: e.message }
      end

      def cleanup_frames_command(restore = false)
        raise 'Đang xuất, hãy chờ hoàn tất trước khi đổi khung scene.' if @job
        model = Sketchup.active_model
        raise 'Đóng edit Group/Component trước khi đổi khung scene.' if model.active_path
        if !restore
          count = SceneFrame.cleanup_state(model)[:count]
          question = "Bỏ khung xám của tất cả #{count} scene có khung trong model và view hiện tại?\nÁp dụng cả scene ngoài VGD. Giữ kích thước xuất VGD đã lưu; khung nhìn sẽ theo cửa sổ SketchUp.\nSau đó lưu SKP để gửi. Có lệnh Khôi phục khung nếu cần."
          return { success: false, cancelled: true, message: 'Đã hủy bỏ khung scene.' } unless ::UI.messagebox(question, MB_YESNO) == IDYES
        end
        result = SceneFrame.cleanup(model, restore)
        Sketchup.status_text = "[VGD] #{result[:message]}"
        send_event('result', result); send_event('state', state)
        result
      rescue StandardError => error
        ::UI.messagebox("VGD Scenes\n#{error.message}")
        { success: false, message: error.message }
      end

      def initialize_ui
        return if @initialized
        menu = ::UI.menu('Extensions').add_submenu('VGD Scenes')
        open_command = ::UI::Command.new('VGD Scenes · Bảng điều khiển') { open }
        quick_command = ::UI::Command.new('VGD · Tạo/cập nhật 4 view nhanh') { quick_views }
        capture_command = ::UI::Command.new('VGD · Cập nhật view hiện tại') { capture_current_view }
        copy_command = ::UI::Command.new('VGD · Copy scene hiện tại') { transfer_command('copyScenes') }
        paste_command = ::UI::Command.new('VGD · Paste scenes') { transfer_command('pasteScenes') }
        [open_command, quick_command].each do |command|
          command.small_icon = File.join(__dir__, 'icon.svg')
          command.large_icon = File.join(__dir__, 'icon.svg')
        end
        quick_command.small_icon = File.join(__dir__, 'quick_views.svg')
        quick_command.large_icon = File.join(__dir__, 'quick_views.svg')
        capture_command.small_icon = File.join(__dir__, 'update_view.svg')
        capture_command.large_icon = File.join(__dir__, 'update_view.svg')
        open_command.tooltip = 'VGD Scenes · Tạo scene, mặt cắt, quản lý và xuất ảnh/PDF'
        quick_command.tooltip = 'VGD · 4 view nhanh: ISO, TOP, FRONT, RIGHT từ đối tượng chọn'
        capture_command.tooltip = 'VGD · Lưu view hiện tại vào scene đang chọn'
        capture_command.status_bar_text = 'Lưu camera, hiển thị, mặt cắt và khung hiện tại vào scene đang chọn.'
        [[copy_command, 'copy_scene.svg'], [paste_command, 'paste_scene.svg']].each do |command, icon|
          command.small_icon = File.join(__dir__, icon)
          command.large_icon = File.join(__dir__, icon)
        end
        copy_command.tooltip = 'VGD · Copy camera và khung của scene đang chọn (đã lưu)'
        paste_command.tooltip = 'VGD · Paste bộ scene từ file khác; chọn trước khi nhập'
        menu.add_item(open_command); menu.add_item(quick_command); menu.add_item(capture_command)
        @toolbar = ::UI::Toolbar.new('VGD Scenes')
        @toolbar.add_item(open_command); @toolbar.add_item(quick_command); @toolbar.add_item(capture_command)
        @toolbar.add_item(copy_command); @toolbar.add_item(paste_command)
        menu.add_item(copy_command); menu.add_item(paste_command)
        menu.add_item('VGD · Xuất toàn bộ góc scene ra JSON') { transfer_command('saveScenes') }
        menu.add_item('VGD · Nhập góc scene từ JSON') { transfer_command('loadScenes') }
        menu.add_item('VGD · Bỏ khung xám tất cả scene để gửi SKP') { cleanup_frames_command }
        menu.add_item('VGD · Khôi phục khung scene đã bỏ') { cleanup_frames_command(true) }
        menu.add_item('Hiện thanh công cụ VGD Scenes') { @toolbar.show }
        @initialized = true
      end
    end
    initialize_ui
  end
end
