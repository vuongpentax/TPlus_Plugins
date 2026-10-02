# frozen_string_literal: true
module VGD
  module Scenes
    class ExportJob
      attr_reader :model
      PAPER = { 'A4_L' => [297, 210], 'A4_P' => [210, 297], 'A3_L' => [420, 297], 'A3_P' => [297, 420] }.freeze
      def initialize(model, pages, opts, destination, callback)
        @model = model; @pages = pages; @opts = opts; @destination = destination; @callback = callback
        @frames = pages.map do |page|
          base = SceneFrame.read(page, opts)
          Scenes.export_dimensions(base, opts['export_scale']).merge('aspect' => base['width'].to_f / base['height'])
        rescue StandardError => e
          raise ArgumentError, "#{page.name}: #{e.message}"
        end
        @index = 0; @files = []; @errors = []; @cancelled = false; @done = false
        @timer = nil; @tmp = nil; @state = nil
      end

      def cancel
        @cancelled = true
      end

      def start
        raise ArgumentError, 'Đóng chế độ edit Group/Component trước khi xuất scene.' if @model.active_path
        if @opts['format'] == 'pdf'
          raise 'SketchUp này không có API xuất PDF LayOut.' unless defined?(Layout::Document) && Layout::Document.instance_methods.include?(:export)
        end
        @state = ViewState.new(@model)
        @transition = @model.options['PageOptions']['ShowTransition']
        @model.options['PageOptions']['ShowTransition'] = false
        @previous_suspended = FrameTool.suspended
        FrameTool.suspended = true
        @tmp = Dir.mktmpdir('vgd-scenes-')
        schedule { select_next }
      rescue StandardError => e
        finish(false, e.message)
      end

      def schedule(&block)
        @timer = ::UI.start_timer(0.12, false) { @timer = nil; block.call }
      end

      def valid_job?
        raise 'Đã đổi/đóng model trong lúc xuất. Tác vụ đã dừng.' unless @model.valid? && Sketchup.active_model == @model
        raise 'Đã vào chế độ edit trong lúc xuất. Tác vụ đã dừng.' if @model.active_path
        !@cancelled
      end

      def select_next
        return finish(false, 'Đã hủy xuất.') unless valid_job?
        return complete if @index >= @pages.length
        page = @pages[@index]
        raise 'Một scene đã bị xóa trong lúc xuất.' unless page.valid?
        @model.pages.selected_page = page
        @model.active_view.refresh
        @callback.call(:progress, { current: @index + 1, total: @pages.length, name: page.name })
        schedule { capture_current }
      rescue StandardError => e
        finish(false, e.message)
      end

      def capture_current
        return finish(false, 'Đã hủy xuất.') unless valid_job?
        page = @pages[@index]
        raise 'Góc nhìn đã đổi trong lúc xuất. Hãy xuất lại và giữ model ổn định.' unless page.valid? && @model.pages.selected_page == page
        extension = @opts['format'] == 'jpg' ? 'jpg' : 'png'
        temporary = File.join(@tmp, format('%04d.%s', @index + 1, extension))
        begin
          frame = @frames[@index]
          # A live fit/ratio preview must not replace an owned scene's saved camera.
          camera = Scenes.camera_copy(SceneStore.owned?(page) ? page.camera : @model.active_view.camera)
          camera.aspect_ratio = frame['aspect']
          @model.active_view.camera = camera
          @model.active_view.refresh
          success = @model.active_view.write_image(filename: temporary, width: frame['width'], height: frame['height'],
            antialias: true, compression: 0.95, transparent: extension == 'png' && @opts['format'] == 'png' && @opts['transparent'])
          raise 'SketchUp không ghi được ảnh.' unless success && File.file?(temporary) && File.size(temporary) > 0
          if @opts['format'] == 'pdf'
            @files << { page: page.name, path: temporary, width: frame['width'], height: frame['height'] }
          else
            output = Scenes.available_path(@destination, format('%02d_%s', @index + 1, page.name), extension)
            FileUtils.mv(temporary, output)
            @files << { page: page.name, path: output, width: frame['width'], height: frame['height'] }
          end
        rescue StandardError => e
          @errors << { page: page.name, error: e.message }
        end
        @index += 1
        schedule { select_next }
      rescue StandardError => e
        finish(false, e.message)
      end

      def complete
        if @opts['format'] == 'pdf'
          raise "Không tạo PDF: #{@errors.length} scene xuất ảnh thất bại. Không tạo hồ sơ thiếu trang." unless @errors.empty?
          build_pdf
        end
        finish(@errors.empty?, @errors.empty? ? "Đã xuất #{@files.length} scene." : "Đã xuất #{@files.length}/#{@pages.length} scene; #{@errors.length} lỗi.")
      rescue StandardError => e
        finish(false, e.message)
      end

      def build_pdf
        doc = Layout::Document.new
        paper = PAPER.fetch(@opts['paper'])
        pw, ph = paper.map { |mm| mm / 25.4 }
        doc.page_info.width = pw; doc.page_info.height = ph
        layer = doc.layers.first
        padding = 10.0 / 25.4
        available_w = pw - padding * 2; available_h = ph - padding * 2
        @files.each_with_index do |item, index|
          aspect = item[:width].to_f / item[:height]
          width = [available_w, available_h * aspect].min; height = width / aspect
          x = (pw - width) / 2.0; y = (ph - height) / 2.0
          page = index.zero? ? doc.pages.first : doc.pages.add(item[:page])
          page.name = item[:page]
          image = Layout::Image.new(item[:path], Geom::Bounds2d.new(x, y, width, height))
          doc.add_entity(image, layer, page)
        end
        raise 'PDF không đủ số trang đã chọn.' unless doc.pages.count == @pages.length
        temporary_pdf = File.join(@tmp, 'VGD_scenes.pdf')
        doc.export(temporary_pdf)
        raise 'LayOut không tạo được PDF hợp lệ.' unless File.file?(temporary_pdf) && File.size(temporary_pdf) > 100 && File.binread(temporary_pdf, 5) == '%PDF-'
        raise 'Tệp đích xuất hiện trong lúc xuất; hãy chọn tên khác.' if File.exist?(@destination)
        FileUtils.mv(temporary_pdf, @destination)
      end

      def finish(success, message)
        return if @done
        @done = true
        ::UI.stop_timer(@timer) if @timer
        restore_error = nil
        begin
          if @model.valid?
            @model.options['PageOptions']['ShowTransition'] = @transition unless @transition.nil?
            @state.restore if @state
          end
        rescue StandardError => e
          restore_error = e.message
          success = false
          message += " Không phục hồi đủ trạng thái: #{e.message}"
        ensure
          FrameTool.suspended = @previous_suspended || false
          @model.active_view.invalidate if @model.valid?
          begin
            FileUtils.remove_entry_secure(@tmp) if @tmp && File.directory?(@tmp)
          rescue StandardError => cleanup_error
            message += " Không dọn được thư mục tạm: #{cleanup_error.message}"
          end
        end
        report = { success: success, cancelled: @cancelled, message: message, count: @files.length,
          total: @pages.length, errors: @errors, path: @opts['format'] == 'pdf' ? (success ? @destination : nil) : @destination,
          files: @opts['format'] == 'pdf' ? [] : @files, restore_error: restore_error }
        @callback.call(:complete, report)
      end
    end
  end
end
