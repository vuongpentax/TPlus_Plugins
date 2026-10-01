from pathlib import Path
root=Path('cabinet_work/TPlus_Cabinet')
old=Path('cabinet_dev/main_original.rb').read_text()
defaults=old.split('    def default_params\n',1)[1].split('\n    def create_new_cabinet_at',1)[0]
defaults=defaults.replace('"max_compartment_w" => 1200.0','"max_compartment_w" => 900.0')
defaults=defaults.replace('"w" => 800.0,', '''"back_mode" => "Âm", "module_mode" => "Chung vách", "module_widths" => "", "module_target_w" => 800.0,
        "front_bevel" => false, "bevel_lip" => 2.0, "snap_step" => 50.0,
        "w" => 800.0,''')
(root/'defaults.rb').write_text("# frozen_string_literal: true\nmodule TPlus_Cabinet\n  def self.default_params\n"+defaults+"\nend\n")
