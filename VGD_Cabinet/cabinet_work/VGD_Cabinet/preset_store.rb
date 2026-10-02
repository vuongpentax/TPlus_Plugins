# frozen_string_literal: true
require 'json'
require 'fileutils'
require 'securerandom'
module VGD_Cabinet
  # User data lives outside the installation so reinstall/reload cannot erase it.
  class PresetStore
    def initialize(path, defaults:, legacy:)
      @path=path; @defaults=defaults; @legacy=legacy
    end
    def name!(value)
      name=value.to_s.strip
      raise ModelingRules::Invalid,'Tên mẫu cần 1–80 ký tự, không có ký tự điều khiển.' if name.empty? || name.length>80 || name.match?(/[\x00-\x1f\x7f]/)
      name
    end
    def decode(text)
      doc=JSON.parse(text)
      raise 'File mẫu sai định dạng.' unless doc.is_a?(Hash) && doc['schema']==1 && doc['presets'].is_a?(Hash)
      values=doc['presets']
      values.each { |name,params| name!(name); raise 'Thông số mẫu sai định dạng.' unless params.is_a?(Hash) }
      folded=values.keys.map(&:downcase)
      raise 'File mẫu chứa tên trùng.' unless folded.uniq.size==folded.size
      values
    end
    def read_current
      decode(File.read(@path,encoding:'UTF-8'))
    rescue StandardError => error
      raise "Không đọc được mẫu: #{error.message}. Giữ nguyên file tại #{@path}." unless File.file?(@path+'.bak')
      values=decode(File.read(@path+'.bak',encoding:'UTF-8'))
      puts "VGD_Cabinet: khôi phục mẫu từ backup; file chính lỗi: #{error.message}"
      values
    end
    def initial_values
      values=@defaults.call
      @legacy.call.each do |name,params|
        next unless params.is_a?(Hash)
        key=name!(name)
        existing=values.keys.find { |n| n.downcase==key.downcase }
        values.delete(existing) if existing
        values[key]=params
      end
      values
    end
    def locked
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path+'.lock','a') do |lock|
        raise 'Không khóa được file mẫu.' unless lock.flock(File::LOCK_EX)
        begin
          yield
        ensure
          lock.flock(File::LOCK_UN)
        end
      end
    end
    def persist(values)
      text=JSON.generate('schema'=>1,'presets'=>values)
      decode(text)
      temporary=@path+'.'+SecureRandom.hex(8)+'.tmp'
      begin
        File.open(temporary,'wb') { |f| f.write(text); f.flush; f.fsync }
        raise 'Kiểm tra file mẫu không khớp.' unless decode(File.read(temporary,encoding:'UTF-8'))==values
        if File.file?(@path)
          begin
            decode(File.read(@path,encoding:'UTF-8'))
            FileUtils.copy_file(@path,@path+'.bak')
          rescue JSON::ParserError, RuntimeError, ModelingRules::Invalid
            # Keep the last good backup when the current file was damaged.
          end
        end
        File.rename(temporary,@path)
        raise 'Không xác nhận được mẫu đã lưu.' unless read_current==values
      ensure
        File.delete(temporary) if File.file?(temporary)
      end
    end
    def load
      locked do
        return read_current if File.file?(@path)
        # Recover a deleted main file before considering first-time migration.
        values=File.file?(@path+'.bak') ? decode(File.read(@path+'.bak',encoding:'UTF-8')) : initial_values
        persist(values)
        values
      end
    end
    def change(action, name, source=nil, params=nil)
      locked do
        values=if File.file?(@path)
          read_current
        elsif File.file?(@path+'.bak')
          decode(File.read(@path+'.bak',encoding:'UTF-8'))
        else
          initial_values
        end
        name=name!(name)
        source=name!(source) unless source.nil?
        collision=values.keys.find { |key| key.downcase==name.downcase }
        case action
        when 'create'
          raise ModelingRules::Invalid,'Tên mẫu đã tồn tại. Chọn Cập nhật hoặc nhập tên khác.' if collision
          values[name]=params
        when 'update'
          raise ModelingRules::Invalid,'Chọn mẫu còn tồn tại để cập nhật.' unless values.key?(source)
          raise ModelingRules::Invalid,'Cập nhật chỉ đổi thông số. Dùng Đổi tên để sửa tên mẫu.' unless name==source
          values[source]=params
        when 'rename'
          raise ModelingRules::Invalid,'Chọn mẫu còn tồn tại để đổi tên.' unless values.key?(source)
          raise ModelingRules::Invalid,'Tên mới trùng một mẫu khác.' if collision && collision!=source
          values[name]=values.delete(source)
        when 'delete'
          raise ModelingRules::Invalid,'Mẫu không còn tồn tại.' unless values.key?(name)
          values.delete(name)
        else
          raise ModelingRules::Invalid,'Lệnh lưu mẫu không hợp lệ.'
        end
        persist(values)
        values
      end
    end
  end
end
