# frozen_string_literal: true
# Nạp lại riêng T+ Cabinet; không quét Plugins, $LOADED_FEATURES hoặc plugin khác.
module TPlus_Cabinet
  module Development
    class << self
      def ruby_files
        %w[geometry_engine.rb modeling_rules.rb modeling.rb defaults.rb
           ui_renderer.rb draw_tool.rb utilities.rb main43.rb]
      end

      def runtime_root
        File.realpath(__dir__)
      end

      def checked_path(root, name)
        raise 'Tên file nạp lại không hợp lệ.' unless (ruby_files + ['reload.rb', 'TPlus_Cabinet_UI.html']).include?(name)
        path = File.realpath(File.join(root, name))
        raise 'File T+ Cabinet nằm ngoài thư mục runtime.' unless File.dirname(path) == root
        path
      end

      def validate_files(root)
        ruby_files.each do |name|
          path = checked_path(root, name)
          RubyVM::InstructionSequence.compile(File.read(path, mode: 'r:BOM|UTF-8'), path)
        end
        checked_path(root, 'TPlus_Cabinet_UI.html')
      end

      def close_cabinet_dialog
        cabinet = TPlus_Cabinet
        dialog = cabinet.instance_variable_get(:@dialog)
        observed_model = cabinet.instance_variable_get(:@observed_model)
        observer = cabinet.instance_variable_get(:@observer)
        observed_model.selection.remove_observer(observer) if observed_model && observer
        if dialog
          # Thay callback cũ trước khi đóng, tránh callback beta 4 xóa dialog mới.
          dialog.set_on_closed {} if dialog.respond_to?(:set_on_closed)
          dialog.close
        end
        cabinet.instance_variable_set(:@dialog, nil)
        cabinet.instance_variable_set(:@observed_model, nil)
        cabinet.instance_variable_set(:@observer, nil)
      end

      def reload_extension
        return false if @reloading
        if TPlus_Cabinet.respond_to?(:is_updating_from_ui?) && TPlus_Cabinet.is_updating_from_ui?
          UI.messagebox('Đợi thao tác dựng/cập nhật tủ hoàn tất rồi Reload.')
          return false
        end
        @reloading = true
        guard_owned = true
        root = runtime_root
        # Tự nạp phiên bản mới của chính bộ Reload, chỉ từ đường dẫn cố định.
        reload_path = checked_path(root, 'reload.rb')
        RubyVM::InstructionSequence.compile(File.read(reload_path, mode: 'r:BOM|UTF-8'), reload_path)
        Kernel.load(reload_path)
        validate_files(root)
        reopen = TPlus_Cabinet.respond_to?(:dialog_visible?) && TPlus_Cabinet.dialog_visible?
        close_cabinet_dialog
        ruby_files.each { |name| Kernel.load(checked_path(root, name)) }
        TPlus_Cabinet.show_dialog if reopen
        puts "T+ Cabinet #{TPlus_Cabinet::VERSION}: đã nạp lại mã từ #{root}"
        UI.messagebox("Đã nạp lại riêng T+ Cabinet #{TPlus_Cabinet::VERSION}.\nCác plugin khác không được nạp lại.")
        true
      rescue StandardError, SyntaxError, LoadError => error
        puts "T+ Cabinet Reload: #{error.class}: #{error.message}\n#{Array(error.backtrace).first(5).join("\n")}"
        UI.messagebox("Không nạp lại được T+ Cabinet: #{error.message}")
        false
      ensure
        @reloading = false if guard_owned
      end
    end
  end

  def self.reload_extension
    Development.reload_extension
  end
end
