module KintoneSync
  class Migration
    include ::KintoneSync::Base
    def copy_column from_name, to_name, type=nil
      fields={}
      kintone.api.form.get(@app_id)['properties'].each do |field|
        next unless field['code'] == from_name
        options = {}
        field['options'].each_with_index do |option, i|
          options[option] = {label: option, index: i}
        end
        type = type || field['type']
        fields[to_name] = {
          type: type,
          code: to_name,
          label: field['label'],
          options: options
        }
      end
      kintone.set_fields fields
      kintone.deploy
      transfer_data from_name, to_name
    end

    def rename_column before_name, after_name
      copy_column before_name, after_name
      drop_column before_name
    end

    def transfer_data from_name, to_name
      kintone.all.each do |record|
        puts record.inspect
        id = record['$id']['value'].to_i
        param = {}
        val = record[from_name]['value']
        param[to_name] = val
        puts "transfer: #{id}"
        puts param.inspect
        kintone.update! id, param if val
      end
    end

    def drop_column name
      kintone.delete_field name
      kintone.deploy
    end

    def change_column name, type
      before_name = name
      after_name = "_#{name}"
      copy_column before_name, after_name, type
      transfer_data before_name, after_name
      drop_column before_name
    end
  end
end
