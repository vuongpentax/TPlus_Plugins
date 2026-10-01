# encoding: UTF-8
module TPlus
  module Dim
    DEFAULTS = {
      'deep'=>true, 'include_dim'=>true, 'include_text'=>true,
      'change_color'=>true, 'dim_color'=>'#0000FF', 'text_color'=>'#0000FF',
      'arrow'=>'dot', 'text_arrow'=>'dot', 'alignment'=>'aligned', 'position'=>'above',
      'change_offset'=>false, 'offset_mm'=>100.0, 'reset_text'=>false,
      'change_units'=>false, 'unit'=>'mm', 'precision'=>0, 'show_unit'=>true,
      'assign_tags'=>true, 'save_profile'=>true, 'auto_new'=>true,
      'change_font'=>true, 'font'=>'UTM Avo', 'size_pt'=>10.0,
      'font_bold'=>false, 'font_italic'=>false, 'custom_dim'=>true
    }.freeze unless const_defined?(:DEFAULTS, false)
  end
end
