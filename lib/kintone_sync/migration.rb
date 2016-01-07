module KintoneSync
  class Migration
    include ::KintoneSync::Base
    def rename_column from_name, to_name
      fields={}
      kintone.api.form.get(@app_id)['properties'].each do |field|
        next unless field['code'] == from_name
        type = field['type']
        fields[from_name] = {
          type: type,
          code: to_name,
        }
      end
      kintone.update_fields fields
      kintone.deploy
    end

    def fork_column from_name, to_name, type=nil
      fields={}
      kintone.api.form.get(@app_id)['properties'].each do |field|
        next unless field['code'] == from_name
        options = {}
        field['options'].each_with_index do |option, i|
          options[option] = {label: option, index: i}
        end
        type = type2fulltype(type) || field['type']
        fields[to_name] = {
          type: type,
          code: to_name,
          label: field['label'],
          options: options
        }
      end
      kintone.create_fields fields
      kintone.deploy
    end

    def copy_column from_name, to_name
      fork_column from_name, to_name
      transfer_data from_name, to_name
    end

    def transfer_data from_name, to_name
      items = kintone.all
      items.each do |record|
        id = record['$id']['value'].to_i
        param = {}
        val = record[from_name]['value']
        param[to_name] = val
        puts "transfer_data: #{id} (#{from_name} -> #{to_name}, val is #{val.inspect})"
        kintone.update! id, param if val
      end
      puts "#{items.count} items were transferd (#{from_name} -> #{to_name})"
    end

    def drop_column name
      kintone.delete_field name
      kintone.deploy
    end

    def change_column name, type
      tmp_name = "_#{name}"
      rename_column name, tmp_name
      fork_column tmp_name, name, type
      transfer_data tmp_name, name
      drop_column tmp_name
    end
  
    # https://cybozudev.zendesk.com/hc/ja/articles/204529724-%E3%83%95%E3%82%A9%E3%83%BC%E3%83%A0%E3%81%AE%E8%A8%AD%E5%AE%9A%E3%81%AE%E5%A4%89%E6%9B%B4#anchor_changeform_deletefields
    def type2fulltype type = nil
      return nil if type.nil?
      case type
      when 'radio'
        'RADIO_BUTTON' 
      when 'select'
        'DROP_DOWN'
      when 'input'
        'SINGLE_LINE_TEXT'
      when 'textarea'
        'MULTI_LINE_TEXT'
      else
        type
      end
    end
  end
end
