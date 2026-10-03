# frozen_string_literal: true
# Runs ONLY in a new empty SketchUp process, never in the user's working document.
require 'sketchup.rb'
require 'json'
require 'fileutils'
ROOT = File.expand_path('..', __dir__)
OUTPUT = File.join(ROOT, 'outputs', 'native_SU22')
FileUtils.mkdir_p(OUTPUT)
def vgd_native_report(data)
  File.write(File.join(OUTPUT, 'native_report.json'), JSON.pretty_generate(data))
end
UI.start_timer(2, false) do
  begin
    model = Sketchup.active_model
    raise 'Refuse non-empty/user document' unless model.path.empty? && model.entities.count.zero? && model.pages.count.zero?
    require File.join(ROOT, 'runtime', 'vgd_scenes', 'main') unless defined?(VGD::Scenes::SceneStore)
    report = { version: Sketchup.version, ruby: RUBY_VERSION, tests: [], started: Time.now.to_s }
    group = model.entities.add_group
    group.name = "VGD Kiểm tra O'Brien"
    face = group.entities.add_face([0,0,0], [1000.mm,0,0], [1000.mm,600.mm,0], [0,600.mm,0])
    face.reverse! if face.normal.z < 0
    face.pushpull(800.mm)
    group.transform!(Geom::Transformation.rotation(ORIGIN,Z_AXIS,30.degrees))
    model.selection.add(group)
    opts = VGD::Scenes::DEFAULTS.merge('views'=>VGD::Scenes::VIEWS, 'width'=>800,'height'=>600)
    result = VGD::Scenes::SceneStore.generate(model, opts)
    raise result.inspect unless result[:ids].length == 7 && model.pages.count == 7
    report[:tests] << '7 standard views created'
    VGD::Scenes::SceneStore.generate(model, opts)
    raise 'Duplicate scenes' unless model.pages.count == 7
    report[:tests] << 'repeat generation updates without duplicates'
    cuts = opts.merge('section_axis'=>'CUSTOM','normal_x'=>1.0,'normal_y'=>1.0,'normal_z'=>0.0,'section_percent'=>65.0,'section_offset'=>25.4,'section_name'=>'A-A')
    result = VGD::Scenes::SceneStore.generate(model,cuts,true)
    section = VGD::Scenes::SceneStore.find(model,result[:ids].first)
    model.pages.selected_page = section
    planes = VGD::Scenes::SceneStore.planes_for(model, section)
    contexts = VGD::Scenes::SceneStore.entity_contexts(model)
    raise 'Cut not saved' unless !planes.empty? && planes.all? { |plane| contexts.any? { |entities| entities.active_section_plane == plane } }
    report[:tests] << 'custom section saved and active'
    id = section.persistent_id.to_s
    VGD::Scenes::SceneStore.rename(model,id,"Mặt cắt O'Brien")
    VGD::Scenes::SceneStore.update_sources(model,[id])
    report[:tests] << 'rename and source update'
    native_group = model.entities.add_group
    native_group.name='FOREIGN'
    foreign = model.pages.add('Foreign scene')
    remove_page = model.pages.add('Delete test')
    VGD::Scenes::SceneStore.delete(model,[remove_page.persistent_id.to_s])
    raise 'Foreign scene affected' unless foreign.valid?
    report[:tests] << 'scoped delete preserves foreign scene'
    VGD::Scenes.apply_frame(model,opts.merge('grid'=>'thirds'))
    VGD::Scenes::FrameTool.toggle(model,opts)
    model.active_view.refresh
    VGD::Scenes::FrameTool.toggle(model,opts)
    report[:tests] << 'frame/grid tool activated and drawn'
    chosen = [model.pages.first,section]
    queue = %w[png jpg pdf]
    run_export = nil
    run_export = lambda do
      if queue.empty?
        report[:success] = true
        report[:finished] = Time.now.to_s
        vgd_native_report(report)
        VGD::Scenes.open
        next
      end
      format = queue.shift
      destination = format == 'pdf' ? VGD::Scenes.available_path(OUTPUT,'native_scenes','pdf') : File.join(OUTPUT,format)
      FileUtils.mkdir_p(destination) unless format == 'pdf'
      job = VGD::Scenes::ExportJob.new(model,chosen,opts.merge('format'=>format,'transparent'=>true),destination,lambda do |event,data|
        if event == :complete
          report[:tests] << { format: format, result: data }
          unless data[:success] && data[:count] == 2
            report[:success] = false
            vgd_native_report(report)
            next
          end
          UI.start_timer(0.2,false) { run_export.call }
        end
      end)
      job.start
    end
    vgd_native_report(report)
    run_export.call
  rescue Exception => error
    vgd_native_report({ success:false,error:error.message,backtrace:error.backtrace,version:Sketchup.version,ruby:RUBY_VERSION })
    puts "VGD NATIVE TEST: #{error.message}"
  end
end
