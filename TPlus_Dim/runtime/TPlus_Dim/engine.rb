# encoding: UTF-8
module TPlus
  module Dim
    module Engine
      extend self

      def container?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      def locked?(entity)
        container?(entity) && entity.locked?
      end

      def target?(entity, config)
        (config['include_dim'] && dimension?(entity)) || (config['include_text'] && text?(entity))
      end

      def dimension?(entity); entity.is_a?(Sketchup::Dimension) || CustomDim.kind(entity) == 'dimension'; end
      def text?(entity); entity.is_a?(Sketchup::Text) || CustomDim.kind(entity) == 'text'; end

      def children(entity)
        entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      end

      # Path-local ancestry prevents cycles but counts each selected instance separately.
      def inspect_entities(entities, config, stats, ancestry = [])
        entities.each do |entity|
          next unless entity.valid?
          next if CustomDim.redundant_source?(entity)
          if locked?(entity)
            stats[:locked] += 1
          elsif dimension?(entity) && config['include_dim']
            stats[:dimensions] += 1
          elsif text?(entity) && config['include_text']
            stats[:texts] += 1
          elsif config['deep'] && container?(entity) && !CustomDim.view?(entity)
            definition = entity.definition
            next if ancestry.include?(definition)
            stats[:shared] += 1 if definition.instances.length > 1
            inspect_entities(children(entity), config, stats, ancestry + [definition])
          end
        end
        stats
      end

      def token(model, config)
        JSON.generate([
          model.guid, (model.active_path || []).map(&:persistent_id),
          model.selection.to_a.map(&:persistent_id).sort,
          config['deep'], config['include_dim'], config['include_text'],
          fingerprint(model.selection.to_a, config)
        ])
      end

      def fingerprint(entities, config, path = [], ancestry = [])
        entities.flat_map do |entity|
          next [] unless entity.valid?
          next [] if CustomDim.redundant_source?(entity)
          current = path + [entity.persistent_id]
          if locked?(entity)
            [current + ['locked']]
          elsif target?(entity, config)
            [current]
          elsif config['deep'] && container?(entity) && !CustomDim.view?(entity) && !ancestry.include?(entity.definition)
            fingerprint(children(entity),config,current,ancestry+[entity.definition])
          else
            []
          end
        end.sort_by(&:to_s)
      end

      def blocked_context(model)
        path = model.active_path || []
        return 'Ngữ cảnh đang mở nằm trong nhóm khóa.' if path.any? { |e| locked?(e) }
        if path.any? { |e| e.definition.instances.length > 1 }
          return 'Đang sửa trong nhóm/component dùng chung. Đóng chế độ sửa, chọn nhóm chứa dim rồi áp dụng để tách riêng vùng chọn.'
        end
        nil
      end

      def context(model, config)
        stats = inspect_entities(model.selection.to_a, config, { dimensions: 0, texts: 0, locked: 0, shared: 0 })
        delete_config = config.merge('deep' => true, 'include_dim' => true, 'include_text' => true)
        deletions = inspect_entities(model.selection.to_a, delete_config, { dimensions: 0, texts: 0, locked: 0, shared: 0 })
        {
          'dimensions' => stats[:dimensions], 'texts' => stats[:texts],
          'locked' => stats[:locked], 'shared' => stats[:shared],
          'selected' => model.selection.length, 'blocked' => blocked_context(model),
          'context_token' => token(model, config),
          'can_apply' => stats[:dimensions] + stats[:texts] > 0 && blocked_context(model).nil?,
          'can_save_profile' => blocked_context(model).nil?,
          'delete_dimensions' => deletions[:dimensions], 'delete_texts' => deletions[:texts],
          'delete_token' => token(model, delete_config), 'can_delete' => blocked_context(model).nil?
        }
      end

      def validate(config)
        %w[deep include_dim include_text change_color change_offset reset_text change_units show_unit assign_tags save_profile auto_new change_font font_bold font_italic custom_dim].each do |key|
          raise ArgumentError, "Tùy chọn #{key} không hợp lệ." unless [true, false].include?(config[key])
        end
        %w[dim_color text_color].each do |key|
          raise ArgumentError, 'Màu phải ở dạng #RRGGBB.' unless config[key].is_a?(String) && config[key].match?(/\A#[0-9a-fA-F]{6}\z/)
        end
        {
          'arrow' => %w[keep none slash dot closed open],
          'alignment' => %w[keep screen aligned], 'position' => %w[keep above center outside],
          'text_arrow' => %w[keep none slash dot closed open],
          'unit' => %w[mm cm m inch ft]
        }.each do |key, values|
          raise ArgumentError, "Thông số #{key} không hợp lệ." unless values.include?(config[key])
        end
        if config['change_offset']
          config['offset_mm'] = Float(config['offset_mm'])
          raise ArgumentError, 'Khoảng cách dim phải lớn hơn 0 và không quá 1.000.000 mm.' unless config['offset_mm'].finite? && config['offset_mm'] > 0 && config['offset_mm'] <= 1_000_000
        end
        precision = Integer(config['precision'].to_s, 10)
        raise ArgumentError, 'Độ chính xác phải từ 0 đến 4.' unless (0..4).include?(precision)
        config['precision'] = precision
        raise ArgumentError, 'Font không nằm trong bộ font T+.' unless FontBook::FAMILIES.include?(config['font'])
        config['size_pt'] = Float(config['size_pt'])
        raise ArgumentError, 'Cỡ chữ phải từ 1 đến 1000 pt.' unless config['size_pt'].finite? && (1.0..1000.0).cover?(config['size_pt'])
        raise ArgumentError, 'Chữ theo màn hình dùng dim native. Tắt dim riêng T+ hoặc chọn chữ theo đường dim.' if config['custom_dim'] && config['alignment'] == 'screen'
        config.select { |key, _value| Dim::DEFAULTS.key?(key) }
      end

      def contains_target?(entities, config, ancestry = [])
        entities.any? do |entity|
          next false unless entity.valid?
          next false if CustomDim.redundant_source?(entity)
          next false if locked?(entity)
          next true if target?(entity, config)
          next false unless config['deep'] && container?(entity) && !CustomDim.view?(entity)
          definition = entity.definition
          !ancestry.include?(definition) && contains_target?(children(entity), config, ancestry + [definition])
        end
      end

      def color_material(model, hex, role)
        name = "T+_#{role}_#{hex.delete('#').upcase}"
        rgb = hex.delete('#').scan(/../).map { |value| value.to_i(16) }
        existing = model.materials[name]
        return existing if existing && [existing.color.red, existing.color.green, existing.color.blue] == rgb
        # Never recolor an existing shared material: unselected dimensions retain their color.
        material = model.materials.add(name)
        material.color = Sketchup::Color.new(*rgb)
        material
      end

      def apply_dimension(entity, config, material, transformation, stats)
        entity = CustomDim.source(entity)
        raise ArgumentError, 'Dim T+ mất nguồn đo; hãy vẽ lại hoặc Undo thao tác xóa nguồn.' unless entity && entity.valid?
        entity.material = material if config['change_color']
        arrows = {
          'none' => Sketchup::Dimension::ARROW_NONE, 'slash' => Sketchup::Dimension::ARROW_SLASH,
          'dot' => Sketchup::Dimension::ARROW_DOT, 'closed' => Sketchup::Dimension::ARROW_CLOSED,
          'open' => Sketchup::Dimension::ARROW_OPEN
        }
        entity.arrow_type = arrows.fetch(config['arrow']) unless config['arrow'] == 'keep'
        entity.has_aligned_text = config['alignment'] == 'aligned' unless config['alignment'] == 'keep'
        if entity.is_a?(Sketchup::DimensionLinear)
          positions = {
            'above' => Sketchup::DimensionLinear::ALIGNED_TEXT_ABOVE,
            'center' => Sketchup::DimensionLinear::ALIGNED_TEXT_CENTER,
            'outside' => Sketchup::DimensionLinear::ALIGNED_TEXT_OUTSIDE
          }
          if config['position'] != 'keep' && entity.has_aligned_text?
            entity.aligned_text_position = positions.fetch(config['position'])
          end
          if config['change_offset']
            vector = entity.offset_vector
            world_length = vector.transform(transformation).length
            if world_length > 1.0e-9
              vector.length = vector.length * config['offset_mm'].mm / world_length
              entity.offset_vector = vector
            else
              stats[:offset_skipped] += 1
            end
          end
        end
        entity.text = '' if config['reset_text']
        entity.layer = stats[:dim_tag] if config['assign_tags'] && stats[:dim_tag]
        if config['custom_dim']
          CustomDim.convert(entity, config, material || entity.material, entity.model)
          stats[:fonts] += 1
        elsif CustomDim.source?(entity)
          CustomDim.restore(entity)
        end
        stats[:dimensions] += 1
      end

      def apply_text(entity, config, material, stats)
        entity = CustomDim.source(entity)
        raise ArgumentError, 'Text T+ mất nguồn ghi chú.' unless entity && entity.valid?
        entity.material = material
        arrows = {
          'none' => Sketchup::Dimension::ARROW_NONE, 'slash' => Sketchup::Dimension::ARROW_SLASH,
          'dot' => Sketchup::Dimension::ARROW_DOT, 'closed' => Sketchup::Dimension::ARROW_CLOSED,
          'open' => Sketchup::Dimension::ARROW_OPEN
        }
        entity.arrow_type = arrows.fetch(config['text_arrow']) unless config['text_arrow'] == 'keep'
        entity.layer = stats[:text_tag] if config['assign_tags'] && stats[:text_tag]
        if config['custom_dim'] && config['change_font'] && entity.has_leader?
          CustomDim.convert(entity, config, material, entity.model)
          stats[:fonts] += 1
        elsif config['custom_dim'] && CustomDim.source?(entity)
          previous = JSON.parse(CustomDim.partner(entity).get_attribute(CustomDim::DICT, 'config'))
          font_settings = previous.select { |key,_| %w[font size_pt font_bold font_italic].include?(key) }
          CustomDim.convert(entity, config.merge(font_settings), material, entity.model)
        elsif config['change_font'] && entity.respond_to?(:font=)
          FontBook.register_private
          entity.font = { name: config['font'], size: config['size_pt'].round,
                          bold: config['font_bold'], italic: config['font_italic'] }
          stats[:fonts] += 1
        elsif config['change_font']
          stats[:fonts_skipped] += 1
        end
        CustomDim.restore(entity) if !config['custom_dim'] && CustomDim.source?(entity)
        stats[:texts] += 1
      end

      def mutate(entities, model, config, materials, transformation, stats, ancestry = [])
        entities.each do |entity|
          next unless entity.valid?
          next if CustomDim.redundant_source?(entity)
          if locked?(entity)
            stats[:locked] += 1
          elsif dimension?(entity) && config['include_dim']
            apply_dimension(entity, config, materials[:dim], transformation, stats)
          elsif text?(entity) && config['include_text']
            apply_text(entity, config, materials[:text], stats)
          elsif config['deep'] && container?(entity) && !CustomDim.view?(entity)
            next if ancestry.include?(entity.definition)
            next unless contains_target?(children(entity), config, ancestry + [entity.definition])
            if entity.definition.instances.length > 1
              entity.make_unique
              stats[:unique] += 1
            end
            mutate(children(entity).to_a, model, config, materials,
                   transformation * entity.transformation, stats, ancestry + [entity.definition])
          end
        end
      end

      def apply(model, config, context_token)
        current = context(model, config)
        raise ArgumentError, 'Vùng chọn đã thay đổi. Bấm Lấy vùng chọn rồi áp dụng lại.' unless current['context_token'] == context_token
        raise ArgumentError, current['blocked'] if current['blocked']
        raise ArgumentError, 'Hãy chọn Dim/Text hoặc bật lưu quy chuẩn vào file.' unless current['can_apply'] || config['save_profile'] || config['change_units']
        change_dim = config['change_color'] || config['arrow'] != 'keep' || config['alignment'] != 'keep' || config['position'] != 'keep' || config['change_offset'] || config['reset_text'] || config['assign_tags']
        unless (current['dimensions'] > 0 && change_dim) || (current['texts'] > 0 && config['include_text']) || config['change_units'] || config['save_profile']
          raise ArgumentError, 'Chưa chọn thông số nào cần thay đổi.'
        end
        stats = { dimensions: 0, texts: 0, locked: 0, unique: 0, offset_skipped: 0, fonts: 0, fonts_skipped: 0 }
        started = false
        begin
          model.start_operation('T+ Dim · Chuẩn hóa vùng chọn', true)
          started = true
          materials = {}
          materials[:dim] = color_material(model, config['dim_color'], 'DIM') if config['change_color'] && current['dimensions'] > 0
          materials[:text] = color_material(model, config['text_color'], 'TEXT') if config['include_text'] && current['texts'] > 0
          if config['assign_tags']
            stats[:dim_tag] = model.layers['T+_DIM'] || model.layers.add('T+_DIM') if current['dimensions'] > 0 || config['save_profile']
            stats[:text_tag] = model.layers['T+_TEXT'] || model.layers.add('T+_TEXT') if current['texts'] > 0 || config['save_profile']
          end
          if config['change_units']
            units = model.options['UnitsOptions']
            units['LengthFormat'] = Length::Decimal
            units['LengthUnit'] = { 'inch' => 0, 'ft' => 1, 'mm' => 2, 'cm' => 3, 'm' => 4 }.fetch(config['unit'])
            units['LengthPrecision'] = config['precision']
            units['SuppressUnitsDisplay'] = !config['show_unit']
          end
          original_selection = model.selection.to_a
          originals = original_selection.select { |e| CustomDim.view?(e) }.map { |e| [e,CustomDim.source(e)] }
          mutate(original_selection, model, config, materials, model.edit_transform, stats)
          originals.each { |view,native| model.selection.add(native) if !view.valid? && native && native.valid? }
          model.selection.to_a.each do |entity|
            next unless entity.valid?
            next unless CustomDim.source?(entity)
            view = CustomDim.partner(entity)
            next unless view
            model.selection.remove(entity)
            model.selection.add(view)
          end
          Profile.write(model, config) if config['save_profile']
          model.commit_operation
          started = false
          model.active_view.invalidate
          stats
        rescue StandardError
          model.abort_operation if started
          raise
        end
      end

      def erase_targets(entities, config, stats, ancestry = [])
        entities.each do |entity|
          next unless entity.valid?
          next if CustomDim.redundant_source?(entity)
          if locked?(entity)
            stats[:locked] += 1
          elsif target?(entity, config)
            key = dimension?(entity) ? :dimensions : :texts
            CustomDim.erase(entity)
            stats[key] += 1
          elsif container?(entity) && !CustomDim.view?(entity)
            next if ancestry.include?(entity.definition)
            next unless contains_target?(children(entity), config, ancestry + [entity.definition])
            if entity.definition.instances.length > 1
              entity.make_unique
              stats[:unique] += 1
            end
            erase_targets(children(entity).to_a, config, stats, ancestry + [entity.definition])
          end
        end
      end

      def delete(model, config, delete_token, kind)
        raise ArgumentError, 'Loại đối tượng xóa không hợp lệ.' unless %w[dimensions texts both].include?(kind)
        all_config = config.merge('deep' => true, 'include_dim' => true, 'include_text' => true)
        raise ArgumentError, 'Vùng chọn đã đổi. Lấy vùng chọn và xác nhận xóa lại.' unless token(model, all_config) == delete_token
        blocked = blocked_context(model)
        raise ArgumentError, blocked if blocked
        removal = all_config.merge('include_dim' => kind != 'texts', 'include_text' => kind != 'dimensions')
        raise ArgumentError, 'Vùng chọn không có đối tượng cần xóa.' unless contains_target?(model.selection.to_a, removal)
        stats = { dimensions: 0, texts: 0, locked: 0, unique: 0 }
        started = false
        begin
          model.start_operation('T+ Dim · Xóa Dim/Text trong vùng chọn', true)
          started = true
          erase_targets(model.selection.to_a, removal, stats)
          model.commit_operation
          started = false
          model.active_view.invalidate
          stats
        rescue StandardError
          model.abort_operation if started
          raise
        end
      end
    end
  end
end
