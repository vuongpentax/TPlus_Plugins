# frozen_string_literal: true
require 'sketchup.rb'
require 'uri'
require_relative 'utils'
require_relative 'geometry'
require_relative 'scenes'
require_relative 'frame'
require_relative 'export'
module VGD
  module Scenes
    VERSION = '1.0.0'.freeze unless const_defined?(:VERSION, false)
    class << self
      def state
        model = Sketchup.active_model
        { model: model.object_id.to_s, title: model.title.empty? ? 'Model chưa lưu' : model.title,
          selection: model.selection.count { |e| Geometry.instance?(e) }, editing: !model.active_path.nil?,
          scenes: SceneStore.list(model), settings: settings(model), grid_active: FrameTool.active?, busy: !@job.nil? }
      end

      def send_event(event, data)
        return unless @dialog && @dialog.visible?
        @dialog.execute_script("window.VGDScenes && window.VGDScenes.receive(#{event.to_json}, #{data.to_json});")
      rescue StandardError => e
        puts "[VGD Scenes] Dialog: #{e.message}"
      end

      def sync_frame
        send_event('frame', { active: FrameTool.active? })
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
                 when 'visit'
                   raise 'Đóng edit Group/Component trước khi mở scene.' if model.active_path
                   model.pages.selected_page = SceneStore.find(model, data['id'])
                   { success: true, message: 'Đã mở scene.' }
                 when 'frame', 'fit', 'grid'
                   opts = options(data.fetch('settings'))
                   if action == 'grid'
                     apply_frame(model, opts)
                     FrameTool.toggle(model, opts)
                     { success: true, message: FrameTool.active? ? 'Đã bật khung/lưới. Dùng chuột giữa để Orbit; Esc để tắt.' : 'Đã tắt lưới.' }
                   else
                     apply_frame(model, opts, action == 'fit')
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
        # Export follows the visible/model scene order, not selection checkbox order.
        pages = model.pages.select { |p| ids.include?(p.persistent_id.to_s) }
        raise ArgumentError, 'Danh sách scene đã thay đổi. Làm mới và chọn lại.' unless pages.length == ids.length
        destination = if opts['format'] == 'pdf'
                        ::UI.savepanel('VGD · Lưu PDF nhiều trang', '', "#{clean_filename(opts['project'].empty? ? 'VGD_Scenes' : opts['project'])}.pdf")
                      else
                        ::UI.select_directory(title: 'VGD · Chọn thư mục xuất ảnh')
                      end
        unless destination
          send_event('result', { success: false, cancelled: true, message: 'Đã hủy chọn nơi lưu.' })
          return
        end
        if opts['format'] == 'pdf'
          destination += '.pdf' unless destination.downcase.end_with?('.pdf')
          # Keep the user's existing output; create a numbered new file.
          destination = available_path(File.dirname(destination), File.basename(destination, '.pdf'), 'pdf') if File.exist?(destination)
        end
        raise ArgumentError, 'Thư mục đích không tồn tại.' unless File.directory?(opts['format'] == 'pdf' ? File.dirname(destination) : destination)
        @job = ExportJob.new(model, pages, opts, destination, lambda do |event, result|
          @job = nil if event == :complete
          @output_folder = opts['format'] == 'pdf' ? File.dirname(result[:path]) : result[:path] if event == :complete && result[:path]
          send_event(event == :complete ? 'exported' : 'progress', result)
          send_event('state', state) if event == :complete
        end)
        send_event('started', { total: pages.length })
        @job.start
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
        @dialog.set_on_closed { @dialog = nil; @job.cancel if @job }
        @dialog.show
      end

      def quick_views
        raise 'Đang xuất, hãy chờ hoàn tất.' if @job
        model = Sketchup.active_model
        result = SceneStore.generate(model, settings(model).merge('views' => %w[ISO TOP FRONT RIGHT BACK LEFT]))
        send_event('state', state)
        Sketchup.status_text = "[VGD] #{result[:message]}"
      rescue StandardError => e
        ::UI.messagebox("VGD Scenes\n#{e.message}")
      end

      def initialize_ui
        return if @initialized
        menu = ::UI.menu('Extensions').add_submenu('VGD Scenes')
        open_command = ::UI::Command.new('VGD Scenes · Bảng điều khiển') { open }
        quick_command = ::UI::Command.new('VGD · Tạo/cập nhật 6 view đối tượng') { quick_views }
        [open_command, quick_command].each do |command|
          command.small_icon = File.join(__dir__, 'icon.svg')
          command.large_icon = File.join(__dir__, 'icon.svg')
        end
        open_command.tooltip = 'VGD Scenes · Tạo scene, mặt cắt, quản lý và xuất ảnh/PDF'
        quick_command.tooltip = 'VGD · Tạo/cập nhật ISO, TOP, FRONT, RIGHT, BACK, LEFT từ đối tượng chọn'
        menu.add_item(open_command); menu.add_item(quick_command)
        @toolbar = ::UI::Toolbar.new('VGD Scenes')
        @toolbar.add_item(open_command); @toolbar.add_item(quick_command)
        menu.add_item('Hiện thanh công cụ VGD Scenes') { @toolbar.show }
        @initialized = true
      end
    end
    initialize_ui
  end
end
