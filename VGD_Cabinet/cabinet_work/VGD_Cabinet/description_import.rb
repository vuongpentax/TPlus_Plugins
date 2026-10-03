# frozen_string_literal: true
require 'json'
module VGD_Cabinet
  module DescriptionImport
    module_function
    class UniqueObject < Hash
      def []=(key, value)
        raise ModelingRules::Invalid, "Thông số trùng: #{key}" if key?(key)
        super
      end
    end
    def enums
      {
        'opt_top'=>['Đỉnh Lọt Hồi','Đỉnh Phủ Hồi'],
        'opt_bottom'=>['Đáy Lọt Hồi','Đáy Phủ Hồi'],
        'opt_left_side'=>['Vuông','Bo Cong'], 'opt_right_side'=>['Vuông','Bo Cong'],
        'back_mode'=>['Âm','Phủ','Không'], 'module_mode'=>['Chung vách','Độc lập'],
        'div_pos'=>['Chia Đều','Bên Trái','Bên Phải'], 'shelf_type'=>['Cố Định','Di Động'],
        'opt_door'=>['Cánh Phủ toàn bộ','Cánh Phủ Hồi Trái','Cánh Phủ Hồi Phải','Cánh Lọt Hồi','Cánh Lọt Lòng','Không Cánh'],
        'door_style'=>['Ván phẳng','Kính khung kim loại','Pano khung gỗ'],
        'metal_finish'=>['Đen','Champagne','Inox'], 'glass_finish'=>['Trong','Trà','Xám'],
        'opt_drawer'=>['Không','Âm','Lộ'], 'drawer_comp_pos'=>['Tất Cả','Trái','Giữa','Phải'],
        'drawer_bottom_mode'=>['Âm hai bên','Âm bốn phía','Phủ dưới'],
        'overheight_join'=>['Đấu Cục Đỉnh','Xà Trên','Xà Dưới']
      }
    end
    def example
      {'format'=>'VGD_CABINET_DESCRIPTION','schema_version'=>1,'units'=>'mm',
       'parameters'=>{'w'=>800,'d'=>600,'h'=>2400,'door_count'=>2,'shelf_count'=>1},
       'assumptions'=>['Kết cấu khuất dùng mặc định VGD; cần kiểm tra trước sản xuất.'],
       'estimated_fields'=>[], 'unsupported_features'=>[]}
    end
    def contract
      {'example'=>example, 'defaults'=>VGD_Cabinet.default_params, 'enums'=>enums}
    end
    def parse(text)
      raise ModelingRules::Invalid,'Dán khối JSON cấu hình từ ChatGPT.' unless text.is_a?(String) && !text.strip.empty?
      raise ModelingRules::Invalid,'Mô tả quá dài (tối đa 200 KB).' if text.bytesize > 200_000
      raw=text.strip
      raw=raw.sub(/\A```(?:json)?\s*\n/i,'').sub(/\n```\z/,'') if raw.start_with?('```')
      data=JSON.parse(raw, object_class: UniqueObject, max_nesting: 12)
      raise ModelingRules::Invalid,'Cấu hình phải là một đối tượng JSON.' unless data.is_a?(Hash)
      unknown=data.keys-%w[format schema_version units parameters assumptions estimated_fields unsupported_features]
      raise ModelingRules::Invalid,"Mục chưa hỗ trợ: #{unknown.join(', ')}" unless unknown.empty?
      raise ModelingRules::Invalid,'Sai format hoặc schema_version; dùng mẫu VGD phiên bản 1.' unless data['format']=='VGD_CABINET_DESCRIPTION' && data['schema_version']==1
      raise ModelingRules::Invalid,'Đơn vị phải là mm; không tự suy đoán cm/m.' unless data['units']=='mm'
      input=data['parameters']
      raise ModelingRules::Invalid,'Thiếu đối tượng parameters.' unless input.is_a?(Hash)
      defaults=VGD_Cabinet.default_params
      unknown=input.keys-defaults.keys
      raise ModelingRules::Invalid,"Thông số chưa hỗ trợ: #{unknown.join(', ')}" unless unknown.empty?
      %w[w d h].each { |k| raise ModelingRules::Invalid,"Thiếu #{k}: nhập kích thước tổng mong muốn, không tự lấy mặc định." unless input.key?(k) }
      input.each do |k,v|
        base=defaults[k]
        valid=case base
              when Numeric then v.is_a?(Numeric) && v.finite?
              when TrueClass, FalseClass then v==true || v==false
              when String then v.is_a?(String) && v.length<=4000
              else false
              end
        raise ModelingRules::Invalid,"#{k}: sai kiểu dữ liệu (số / true,false / chuỗi)." unless valid
        raise ModelingRules::Invalid,"#{k}: chọn #{enums[k].join(' / ')}." if enums[k] && !enums[k].include?(v)
      end
      raise ModelingRules::Invalid,'handle_split_v1 phải là true; móc tay cánh và hộc độc lập.' if input['handle_split_v1']==false
      meta={}
      %w[assumptions estimated_fields unsupported_features].each do |k|
        list=data.fetch(k,[])
        raise ModelingRules::Invalid,"#{k}: cần danh sách chuỗi, tối đa 80 mục." unless list.is_a?(Array) && list.size<=80 && list.all? { |v| v.is_a?(String) && v.length<=500 }
        meta[k]=list
      end
      raise ModelingRules::Invalid,'estimated_fields phải là tên thông số có trong parameters.' unless (meta['estimated_fields']-input.keys).empty?
      p=input.each_with_object({}) { |(key,value),hash| hash[key]=value }
      p['handle_split_v1']=true
      {'door_count'=>'auto_door_count','div_count'=>'auto_divider_wide','is_overheight'=>'auto_overheight','h_bottom'=>'auto_overheight'}.each do |count,flag|
        p[flag]=false if p.key?(count) && !p.key?(flag)
      end
      normalized=VGD_Cabinet.normalize(p)
      adjustments=[]
      if normalized['opt_top']=='Đỉnh Phủ Hồi' && normalized['shadow_gap_h']!=0
        normalized['shadow_gap_h']=0
        adjustments << 'Đỉnh phủ hồi: nẹp trần được đưa về 0 theo quy tắc hiện có.'
      end
      if normalized['is_full_drawer'] && normalized['opt_drawer']=='Không'
        normalized['opt_drawer']='Lộ'
        adjustments << 'Toàn hộc: bật hộc Lộ thay cho Không theo quy tắc hiện có.'
      end
      split=GeometryEngine.resolve_overheight_mm(normalized,normalized['h'])
      if split[:is_overheight]
        adjustments << 'Chiều cao tầng dưới được điều chỉnh theo giới hạn bộ dựng.' if normalized['h_bottom']!=split[:h_bottom]
        normalized['is_overheight']=true
        normalized['h_bottom']=split[:h_bottom]
        top=(normalized['h']-normalized['shadow_gap_h']-normalized['h_bottom']).round(1)
        adjustments << 'h_top được tính từ cao tổng, nẹp và cao tầng dưới.' if input.key?('h_top') && input['h_top']!=top
        normalized['h_top']=top
      end
      normalized=VGD_Cabinet.normalize(normalized)
      widths=ModelingRules.widths(normalized)
      meta.merge('parameters'=>normalized, 'defaulted_fields'=>defaults.keys-p.keys, 'adjustments'=>adjustments,
        'summary'=>"#{normalized['w']} × #{normalized['d']} × #{normalized['h']} mm; #{widths.size} module; #{normalized['door_style']}; đợt/module: #{normalized['shelf_count']}; hộc: #{normalized['opt_drawer']} (#{normalized['drawer_count']} tầng/cụm).",
        'module_summary'=>widths.map { |w| "#{w.round(2)} mm: #{GeometryEngine.effective_divider_count_mm(normalized,w)+1} khoang, #{normalized['opt_door']=='Không Cánh' ? 0 : GeometryEngine.effective_door_count_mm(normalized,w)} cánh" },
        'can_apply'=>meta['unsupported_features'].empty?,
        'can_apply_partial'=>!meta['unsupported_features'].empty?)
    rescue JSON::ParserError, JSON::NestingError
      raise ModelingRules::Invalid,'JSON không hợp lệ. Chỉ dán khối cấu hình, không kèm phần giải thích.'
    end
    def for_apply(text, allow_partial: false, acknowledged_features: nil)
      result=parse(text) # Partial mode never bypasses JSON or geometry validation.
      unless result['can_apply']
        unless allow_partial == true && acknowledged_features == result['unsupported_features']
          raise ModelingRules::Invalid,'Có chi tiết chưa hỗ trợ. Chọn Dựng phần được hỗ trợ và xác nhận đúng danh sách bỏ qua.'
        end
      end
      result
    end
  end
end
