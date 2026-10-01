# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require_relative 'defaults'
require_relative 'font_book'
require_relative 'custom_dim'
require_relative 'engine'
require_relative 'profile'

module TPlus
  module Dim
    extend self
    PREF_KEY = 'TPlus_Dim'.freeze unless const_defined?(:PREF_KEY, false)

    class SelectionWatch < Sketchup::SelectionObserver
      def onSelectionBulkChange(_selection); Dim.queue_sync; end
      def onSelectionAdded(_selection, _entity); Dim.queue_sync; end
      def onSelectionRemoved(_selection, _entity); Dim.queue_sync; end
      def onSelectionCleared(_selection); Dim.queue_sync; end
    end

    class ModelWatch < Sketchup::ModelObserver
      def onActivePathChanged(_model); Dim.queue_sync; end
      def onTransactionUndo(_model); Dim.queue_sync; end
      def onTransactionRedo(_model); Dim.queue_sync; end
      def onTransactionCommit(_model); Dim.queue_sync; end
    end

    class AppWatch < Sketchup::AppObserver
      def onActivateModel(_model); Dim.attach_model; Dim.queue_sync; end
      def onNewModel(_model); Dim.attach_model; Dim.queue_sync; end
      def onOpenModel(_model); Dim.attach_model; Dim.queue_sync; end
    end

    def settings
      return @settings if @settings
      saved = JSON.parse(Sketchup.read_default(PREF_KEY, 'settings', '{}')) rescue {}
      saved = {} unless Sketchup.read_default(PREF_KEY, 'schema', 0) == 2
      saved = Profile.read(Sketchup.active_model) || saved
      @settings = DEFAULTS.merge(saved.is_a?(Hash) ? saved : {})
      # Model-wide changes are always opt-in for each dialog session.
      @settings['change_units'] = false
      @settings
    end

    def attach_model
      model = Sketchup.active_model
      return if @watched_model == model
      detach_model
      @settings = nil
      @watched_model = model
      @selection_watch = SelectionWatch.new
      @model_watch = ModelWatch.new
      model.selection.add_observer(@selection_watch)
      model.add_observer(@model_watch)
    end

    def detach_model
      if @watched_model
        @watched_model.selection.remove_observer(@selection_watch) if @selection_watch
        @watched_model.remove_observer(@model_watch) if @model_watch
      end
      @watched_model = @selection_watch = @model_watch = nil
    rescue StandardError
      @watched_model = @selection_watch = @model_watch = nil
    end

    def queue_sync
      return unless @dialog && @ready
      UI.stop_timer(@sync_timer) if @sync_timer
      @sync_timer = UI.start_timer(0.12, false) { @sync_timer = nil; sync }
    end

    def sync
      return unless @dialog && @ready
      attach_model
      context = Engine.context(Sketchup.active_model, settings)
      context['model_id'] = Sketchup.active_model.guid
      profile = Profile.read(Sketchup.active_model)
      context['profile_active'] = !!(profile && profile['auto_new'])
      context['version'] = '1.1 · beta 2'
      @dialog.execute_script("TPlusDim.receive(#{JSON.generate(context)}, #{JSON.generate(settings)});")
    rescue StandardError => error
      report(error.message, true)
    end

    def report(message, error = false)
      @dialog.execute_script("TPlusDim.status(#{JSON.generate(message)}, #{error ? 'true' : 'false'});") if @dialog && @ready
    end

    def apply_payload(payload)
      data = payload.is_a?(String) ? JSON.parse(payload) : payload
      raise ArgumentError, 'Cấu hình không hợp lệ.' unless data.is_a?(Hash)
      config = Engine.validate(DEFAULTS.merge(data))
      model = Sketchup.active_model
      result = ProfileService.for_model(model).with_paused { Engine.apply(model, config, data['context_token']) }
      @settings = config
      Sketchup.write_default(PREF_KEY, 'settings', JSON.generate(config))
      Sketchup.write_default(PREF_KEY, 'schema', 2)
      sync
      message = "Đã cập nhật #{result[:dimensions]} dim"
      message += " · #{result[:texts]} text" if config['include_text']
      message += " · tách riêng #{result[:unique]} nhóm/component" if result[:unique] > 0
      message += " · bỏ qua #{result[:locked]} nhóm khóa" if result[:locked] > 0
      message += " · #{result[:offset_skipped]} dim không có hướng dịch" if result[:offset_skipped] > 0
      message += ' · đã đổi đơn vị toàn model' if config['change_units']
      message += ' · quy chuẩn lưu trong model (Ctrl+S để lưu SKP)' if config['save_profile']
      message += " · #{result[:fonts_skipped]} Text màn hình giữ font native" if result[:fonts_skipped] > 0
      report(message + '. Có thể Undo để hoàn tác.')
    rescue StandardError => error
      puts "[T+ Dim] #{error.class}: #{error.message}\n#{error.backtrace.join("\n")}"
      sync
      report(error.message, true)
    end

    def delete_payload(payload)
      data = payload.is_a?(String) ? JSON.parse(payload) : payload
      raise ArgumentError, 'Yêu cầu xóa không hợp lệ.' unless data.is_a?(Hash)
      model = Sketchup.active_model
      result = ProfileService.for_model(model).with_paused { Engine.delete(model, DEFAULTS, data['delete_token'], data['kind']) }
      sync
      report("Đã xóa #{result[:dimensions]} dim · #{result[:texts]} text; bỏ qua #{result[:locked]} nhóm khóa. Có thể Undo.")
    rescue StandardError => error
      sync
      report(error.message, true)
    end

    def reload_extension
      load File.join(__dir__,'reload.rb')
    end

    def show_dialog
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        return
      end
      @ready = false
      @settings = nil
      @dialog = UI::HtmlDialog.new(
        dialog_title: 'T+ Dim · Quy chuẩn bản vẽ', preferences_key: PREF_KEY,
        scrollable: true, resizable: true, width: 580, height: 680,
        min_width: 470, min_height: 530, style: UI::HtmlDialog::STYLE_DIALOG
      )
      @dialog.set_file(File.join(__dir__, 'dialog.html'))
      @dialog.add_action_callback('ready') { @ready = true; attach_model; sync }
      @dialog.add_action_callback('refresh') do |_, payload|
        data = payload.is_a?(String) ? JSON.parse(payload) : payload
        if data.is_a?(Hash)
          settings['deep'] = data['deep'] == true
          settings['include_text'] = data['include_text'] == true
          settings['include_dim'] = data['include_dim'] == true
        end
        sync
      end
      @dialog.add_action_callback('apply') { |_, payload| apply_payload(payload) }
      @dialog.add_action_callback('delete') { |_, payload| delete_payload(payload) }
      @dialog.add_action_callback('model_info') do |_, page|
        ok = UI.show_model_info(page == 'Text' ? 'Text' : 'Dimensions')
        report('Không mở được Model Info. Mở Window → Model Info trong SketchUp.', true) unless ok
      end
      @dialog.add_action_callback('close') { @dialog.close if @dialog }
      @dialog.set_on_closed do
        UI.stop_timer(@sync_timer) if @sync_timer
        @sync_timer = nil
        @dialog = nil
        @ready = false
        detach_model
        Sketchup.remove_observer(@app_watch) if @app_watch
        @app_watch = nil
      end
      @app_watch ||= AppWatch.new
      Sketchup.add_observer(@app_watch)
      @dialog.show
    end

    ProfileService.install
    unless @command
      @command = command = UI::Command.new('T+ Dim') { show_dialog }
      command.small_icon = command.large_icon = File.join(__dir__, 'dim.svg')
      command.tooltip = 'T+ Dim · Chuẩn hóa dim được chọn'
      command.status_bar_text = 'Quét chọn dim hoặc nhóm chứa dim, rồi mở T+ Dim.'
      UI.menu('Extensions').add_item(command) unless file_loaded?(__FILE__)
      unless @toolbar
        @toolbar = UI::Toolbar.new('T+ Dim')
        @toolbar.add_item(command)
      end
      UI.menu('Extensions').add_item('Hiện toolbar T+ Dim') { @toolbar.show }
      UI.menu('Extensions').add_item('Nạp lại T+ Dim') { reload_extension }
      # SketchUp owns toolbar placement. Never show/restore/hide at startup.
      file_loaded(__FILE__)
    end
  end
end
