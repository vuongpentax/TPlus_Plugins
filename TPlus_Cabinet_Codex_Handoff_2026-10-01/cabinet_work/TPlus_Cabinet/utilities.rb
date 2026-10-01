# frozen_string_literal: true

require 'set'

# Tách bản sao trước khi sửa definition hoặc hình học bên trong.
module TPlusUtilityScope
  def self.container?(entity)
    entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
  end

  def self.prepare(entity, ancestors = Set.new)
    return unless entity.valid? && container?(entity)
    raise 'Đối tượng đang khóa. Hãy mở khóa trước khi chạy tiện ích.' if entity.locked?
    original_definition = entity.definition
    raise 'Component lồng vòng; không thể xử lý.' if ancestors.include?(original_definition)
    path = ancestors.dup.add(original_definition)
    entity.make_unique
    entity.definition.entities.to_a.each { |child| prepare(child, path) }
  end

  def self.copy_attributes(source, destination)
    dictionaries = source.attribute_dictionaries
    return unless dictionaries
    dictionaries.each do |dictionary|
      next if ['dynamic_attributes', 'SU_InstanceSet'].include?(dictionary.name)
      dictionary.each_pair { |key, value| destination.set_attribute(dictionary.name, key, value) }
    end
  end

  def self.sync_selection
    TPlus_Cabinet.sync_current_selection if defined?(TPlus_Cabinet) && TPlus_Cabinet.respond_to?(:sync_current_selection)
  end
end

# =========================================================================
# MODULE T+_EXPLODE v1.0 (RÃ NHÓM LỒNG TỦ, GIỮ NGUYÊN TẤM VÁCH ĐỘC LẬP & XÓA KHỐI ẨN)
# =========================================================================
module TPlusExplode
  # Dọn dẹp từ điển thuộc tính Dynamic Component
  def self.clean_dc_dictionaries(entity)
    return unless entity.valid?

    if entity.respond_to?(:attribute_dictionaries) && entity.attribute_dictionaries
      begin; entity.attribute_dictionaries.delete('dynamic_attributes'); rescue; end
      begin; entity.attribute_dictionaries.delete('SU_InstanceSet'); rescue; end
    end

    if entity.respond_to?(:definition) && entity.definition.respond_to?(:attribute_dictionaries) && entity.definition.attribute_dictionaries
      begin; entity.definition.attribute_dictionaries.delete('dynamic_attributes'); rescue; end
      begin; entity.definition.attribute_dictionaries.delete('SU_InstanceSet'); rescue; end
    end
  end

  # Xóa các đối tượng bị ẩn (hidden / !visible) đệ quy
  def self.remove_hidden_entities(entities_container)
    hidden_ents = []
    entities_container.each do |ent|
      next unless ent.valid?
      if (!ent.visible? || ent.hidden?)
        hidden_ents << ent
      elsif ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
        sub_ents = ent.is_a?(Sketchup::ComponentInstance) ? (ent.definition.entities rescue nil) : (ent.entities rescue nil)
        remove_hidden_entities(sub_ents) if sub_ents
      end
    end
    unless hidden_ents.empty?
      begin; entities_container.erase_entities(hidden_ents); rescue; end
    end
  end

  # Rã các nhóm lồng/khối con trung gian (ví dụ: Thùng Ngăn Kéo) để đưa từng tấm vách riêng biệt lên làm con trực tiếp của Tủ Cha
  def self.flatten_nested_containers(parent_grp)
    return unless parent_grp.valid? && parent_grp.is_a?(Sketchup::Group)

    ents = parent_grp.entities
    loop do
      # Tìm nhóm hoặc component có chứa nhóm/component con bên trong (intermediate container)
      containers = ents.select do |e|
        next false unless e.valid?
        if e.is_a?(Sketchup::Group)
          e.entities.any? { |child| child.is_a?(Sketchup::Group) || child.is_a?(Sketchup::ComponentInstance) }
        elsif e.is_a?(Sketchup::ComponentInstance)
          e.definition.entities.any? { |child| child.is_a?(Sketchup::Group) || child.is_a?(Sketchup::ComponentInstance) }
        else
          false
        end
      end

      break if containers.empty?

      containers.each do |c|
        next unless c.valid?
        clean_dc_dictionaries(c)
        c.explode
        raise 'Không rã được nhóm lồng; thao tác đã hủy.' if c.valid?
      end
    end
  end

  # Chuyển ComponentInstance tấm vách con thành Group độc lập
  def self.convert_component_to_group(parent_ents, instance)
    return nil unless instance.valid? && instance.is_a?(Sketchup::ComponentInstance)
    trans = instance.transformation
    layer = instance.layer
    name  = instance.name.empty? ? instance.definition.name : instance.name
    defn  = instance.definition

    new_grp = parent_ents.add_group
    new_grp.transformation = trans
    new_grp.layer = layer
    new_grp.name = name
    new_grp.material = instance.material
    TPlusUtilityScope.copy_attributes(defn, new_grp)
    TPlusUtilityScope.copy_attributes(instance, new_grp)

    temp_inst = new_grp.entities.add_instance(defn, Geom::Transformation.new)
    clean_dc_dictionaries(temp_inst)
    temp_inst.explode
    raise 'Không chuyển được component con thành group.' if temp_inst.valid?

    clean_dc_dictionaries(new_grp)

    if instance.valid?
      instance.erase!
    end
    new_grp
  end

  # Xử lý các chi tiết con bên trong Tủ Cha
  def self.process_cabinet_children(parent_grp)
    ents = parent_grp.entities

    # 1. Xóa toàn bộ chi tiết ẩn bên trong
    remove_hidden_entities(ents)

    # 2. Rã các nhóm lồng trung gian (như Thùng Ngăn Kéo) để các tấm vách thành con trực tiếp của Tủ Cha
    flatten_nested_containers(parent_grp)

    # 3. Chuyển toàn bộ Component tấm vách con thành Group độc lập
    components = ents.grep(Sketchup::ComponentInstance).to_a
    components.each do |comp|
      next unless comp.valid?
      convert_component_to_group(ents, comp)
    end

    # 4. Dọn dẹp thuộc tính Dynamic Component cho tất cả các tấm vách con
    groups = ents.grep(Sketchup::Group).to_a
    groups.each do |grp|
      next unless grp.valid?
      clean_dc_dictionaries(grp)
    end
  end

  # Xử lý Tủ Cha ngoài cùng (Chuyển thành Group nếu là Component, bảo toàn thuộc tính T+_CABINET & tên)
  def self.process_top_cabinet(top_ent)
    return nil unless top_ent.valid?
    return nil if (!top_ent.visible? || top_ent.hidden?)

    # Lưu lại thuộc tính tủ
    is_cab = top_ent.get_attribute('TPlus_Cabinet', 'is_cabinet', false) ||
             (top_ent.respond_to?(:definition) && top_ent.definition.get_attribute('TPlus_Cabinet', 'is_cabinet', false))
    params_json = top_ent.get_attribute('TPlus_Cabinet', 'params_json', nil) ||
                  (top_ent.respond_to?(:definition) && top_ent.definition.get_attribute('TPlus_Cabinet', 'params_json', nil))
    params_raw = top_ent.get_attribute('TPlus_Cabinet', 'params', nil) ||
                 (top_ent.respond_to?(:definition) && top_ent.definition.get_attribute('TPlus_Cabinet', 'params', nil))

    parent_grp = nil

    if top_ent.is_a?(Sketchup::ComponentInstance)
      model = Sketchup.active_model
      parent_ents = (top_ent.parent.entities rescue model.active_entities)

      trans = top_ent.transformation
      layer = top_ent.layer
      name  = top_ent.name.empty? ? top_ent.definition.name : top_ent.name
      defn  = top_ent.definition

      parent_grp = parent_ents.add_group
      parent_grp.transformation = trans
      parent_grp.layer = layer
      parent_grp.name = name
      parent_grp.material = top_ent.material
      TPlusUtilityScope.copy_attributes(defn, parent_grp)
      TPlusUtilityScope.copy_attributes(top_ent, parent_grp)

      temp_inst = parent_grp.entities.add_instance(defn, Geom::Transformation.new)
      clean_dc_dictionaries(temp_inst)
      temp_inst.explode
      raise 'Không chuyển được tủ cha thành group.' if temp_inst.valid?

      if top_ent.valid?
        top_ent.erase!
      end
    elsif top_ent.is_a?(Sketchup::Group)
      parent_grp = top_ent
      clean_dc_dictionaries(parent_grp)
    else
      return nil
    end

    # Gán lại thuộc tính T+_CABINET lên Tủ Cha để tiếp tục cho phép chọn và Cập nhật tủ sau này
    if is_cab
      parent_grp.set_attribute('TPlus_Cabinet', 'is_cabinet', true)
      parent_grp.set_attribute('TPlus_Cabinet', 'params_json', params_json) if params_json
      parent_grp.set_attribute('TPlus_Cabinet', 'params', params_raw) if params_raw
    end

    # Xử lý toàn bộ các chi tiết con bên trong Tủ Cha
    process_cabinet_children(parent_grp)

    parent_grp
  end

  # Thuật toán FixIt 101 (Solidify & Dọn dẹp hình học đệ quy từ Anton Synytsia)
  def self.fix_it(ents, recursive = true)
    return unless ents
    entities = ents.is_a?(Sketchup::Entities) ? ents : (ents.respond_to?(:grep) ? ents : nil)
    return unless entities

    temp_pt = Geom::Point3d.new(3.14, 1.59, 2.65)

    # 1. Xóa mặt trùng / đè lên nhau (Overlapping / Duplicate faces)
    to_remove = []
    entities.grep(Sketchup::Edge).each do |e|
      next unless e.valid?
      e.faces.each do |f1|
        next unless f1.valid?
        e.faces.each do |f2|
          next unless f2.valid?
          next if f1 == f2
          next unless (f1.normal.parallel?(f2.normal) rescue false)
          next if to_remove.include?(f1) || to_remove.include?(f2)
          v1 = (f1.outer_loop.vertices rescue [])
          v2 = (f2.outer_loop.vertices rescue [])
          if !v1.empty? && (v1 - v2).empty? && (v2 - v1).empty?
            to_remove << f2
          end
        end
      end
    end
    to_remove.each { |e| begin; e.erase!; rescue; end if e.valid? }
    to_remove.clear

    # 2. Tạo mặt tại vị trí viền cô đơn (Find faces)
    size = (entities.to_a.size rescue 0)
    entities.grep(Sketchup::Edge).each do |e|
      e.find_faces if e.valid? && e.faces.size == 1
    end

    # Xóa các mặt tự sinh nằm bên trong khối solid
    all_ents = (entities.to_a rescue [])
    if all_ents.size > size
      all_ents[size..-1].each do |face|
        next unless face.is_a?(Sketchup::Face) && face.valid?
        face.edges.each do |edge|
          if edge.valid? && edge.faces.size > 2
            to_remove << face
            break
          end
        end
      end
    end
    to_remove.each { |e| begin; e.erase!; rescue; end if e.valid? }
    to_remove.clear

    # 3. Xóa vách ẩn nội bộ (Internal Faces)
    entities.grep(Sketchup::Face).each do |e|
      next unless e.valid?
      remove = true
      e.edges.each do |edge|
        next if edge.faces.size > 2
        remove = false
        break
      end
      to_remove << e if remove
    end
    to_remove.each do |e|
      next unless e.valid?
      begin; e.erase!; rescue; end
    end
    to_remove.clear

    # 4. Xóa cạnh rác & gộp mặt đồng phẳng (Coplanar & Single edges)
    2.times do
      entities.grep(Sketchup::Edge).each do |e|
        next unless e.valid?
        if e.faces.empty?
          begin; e.erase!; rescue; end
          next
        end
        next if e.faces.size != 2
        f1, f2 = e.faces
        if f1.valid? && f2.valid? && (f1.normal.parallel?(f2.normal) rescue false) && (f1.material == f2.material rescue false) && (f1.back_material == f2.back_material rescue false)
          vertices = f1.vertices + f2.vertices rescue []
          plane = Geom.fit_plane_to_points(vertices) rescue nil
          safe = plane ? vertices.all? { |v| v.position.on_plane?(plane) rescue false } : false
          if safe
            begin; e.erase!; rescue; end
          end
        end
      end
    end

    # 5. Sửa cạnh bị gãy (Repair split edges)
    repaired = []
    entities.grep(Sketchup::Edge).each do |e|
      next unless e.valid?
      e.vertices.each do |v|
        next unless v.valid?
        if v.edges.size == 2
          v1 = (v.edges[0].line[1] rescue nil)
          v2 = (v.edges[1].line[1] rescue nil)
          if v1 && v2 && (v1.parallel?(v2) rescue false)
            repaired << e
            l = (entities.add_line(v.position, temp_pt) rescue nil)
            to_remove << l if l
          end
        end
      end
    end
    to_remove.each { |e| begin; e.erase!; rescue; end if e.valid? }
    to_remove.clear

    # 6. Sửa đường cong bị đứt đoạn (Repair curves)
    entities.grep(Sketchup::Edge).each do |e|
      next unless e.valid?
      next unless (e.curve rescue nil)
      e.vertices.each do |v|
        next unless v.valid?
        found = false
        v.edges.each do |edge|
          next unless edge.valid?
          next unless (edge.curve rescue nil)
          next if edge == e || ((edge.curve.edges.include?(e)) rescue false)
          next if edge.faces.size != e.faces.size
          found = true
          break
        end
        next unless found
        v.edges.each do |edge|
          next unless edge.valid?
          if (edge.curve rescue nil)
            next
          end
          edge.soft = true rescue nil
          edge.smooth = true rescue nil
        end
        l = (entities.add_line(v.position, temp_pt) rescue nil)
        begin; l.erase!; rescue; end if l
      end
      begin
        e.explode_curve if (e.curve && e.curve.count_edges == 1)
      rescue
      end
    end

    # 7. Đưa nét và mặt về Layer0 / Untagged
    control_types = [Sketchup::Edge, Sketchup::Face, Sketchup::ConstructionLine, Sketchup::ConstructionPoint]
    entities.each do |e|
      next unless e.valid?
      if control_types.include?(e.class) && (e.layer.name != 'Layer0' rescue false)
        e.layer = Sketchup.active_model.layers[0]
      end
    end

    # 8. Xử lý đệ quy cho Group & Component con
    return unless recursive
    entities.grep(Sketchup::Group).each do |e|
      fix_it(e.entities, true) if e.valid?
    end
    processed_definitions = []
    entities.grep(Sketchup::ComponentInstance).each do |e|
      next unless e.valid?
      defn = (e.definition rescue nil)
      if defn && !processed_definitions.include?(defn)
        processed_definitions << defn
        fix_it(defn.entities, true)
      end
    end
  end

  # LỆNH CHẠY CHÍNH T+_EXPLODE
  def self.execute_explode
    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox('Chọn Group/Component cần xử lý trước khi chạy T+_EXPLODE.')
      return
    end
    targets = selection.to_a
    scope_text = 'Vùng chọn'

    valid_targets = targets.select { |e| e.valid? && (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) }

    if valid_targets.empty?
      UI.messagebox('Vui lòng chọn tủ hoặc đối tượng Group/Component!')
      return
    end

    model.start_operation("T+_EXPLODE v1.0", true)
    started = true
    valid_targets.each { |entity| TPlusUtilityScope.prepare(entity) }

    processed_count = 0
    processed_groups = []
    valid_targets.each do |top_ent|
      next unless top_ent.valid?
      if (!top_ent.visible? || top_ent.hidden?)
        top_ent.erase!
        next
      end

      res = process_top_cabinet(top_ent)
      if res
        processed_count += 1
        processed_groups << res
      end
    end

    # Áp dụng FixIt 101 dọn dẹp, nối mặt & hóa Solid đệ quy cho các nhóm tủ vừa xử lý
    processed_groups.each do |grp|
      fix_it(grp.entities, true) if grp.valid?
    end

    selection.clear
    processed_groups.each { |group| selection.add(group) if group.valid? }
    model.commit_operation
    started = false
    model.active_view.invalidate
    TPlusUtilityScope.sync_selection

    UI.messagebox("⚡ T+_EXPLODE 1.0 HOÀN TẤT!

- Phạm vi: #{scope_text}
- Đã rã nhóm lồng trung gian (như Thùng Ngăn Kéo), giữ nguyên từng tấm vách độc lập để tiếp tục chỉnh sửa.
- Đã xóa nhóm/vách bị ẩn & áp dụng FixIt 101 tự động hàn mặt, xóa cạnh rác.
- Khối Tủ Cha ngoài cùng được giữ nguyên (Tích hợp thuộc tính T+_CABINET).")
  rescue => error
    model.abort_operation if started
    puts "T+_EXPLODE: #{error.message}\n#{Array(error.backtrace).first(5).join("\n")}"
    UI.messagebox("Không hoàn tất T+_EXPLODE; thao tác đã hủy: #{error.message}")
  end
end

# =========================================================================
# MODULE T+_UNTAG v1.0 (XÓA TAG CON, GIỮ TAG CHA)
# =========================================================================
module TPlusUntag
  def self.clean_selected_tags
    model = Sketchup.active_model
    selection = model.selection

    targets = selection.select { |entity| entity.valid? && TPlusUtilityScope.container?(entity) }
    if targets.empty?
      UI.messagebox('Vui lòng chọn ít nhất một Group hoặc Component!')
      return
    end

    model.start_operation('T+_UNTAG: Xóa Tag Con', true)
    started = true
    targets.each { |entity| TPlusUtilityScope.prepare(entity) }

    count = 0
    reset_internal_tags = Proc.new do |entity, block|
      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        definition = entity.definition
        
        definition.entities.each do |child|
          if child.respond_to?(:layer=) && child.layer != model.layers[0]
            child.layer = model.layers[0]
            count += 1
          end
          block.call(child, block)
        end
      end
    end

    targets.each do |parent_entity|
      reset_internal_tags.call(parent_entity, reset_internal_tags)
    end

    model.commit_operation
    started = false
    model.active_view.invalidate

    UI.messagebox("⚡ T+_UNTAG HOÀN TẤT!

- Đã đưa #{count} đối tượng con về Untagged.
- Tag của khối Cha ngoài cùng được giữ nguyên.")
  rescue => error
    model.abort_operation if started
    puts "T+_UNTAG: #{error.message}\n#{Array(error.backtrace).first(5).join("\n")}"
    UI.messagebox("Không hoàn tất T+_UNTAG; thao tác đã hủy: #{error.message}")
  end
end
