module KintoneSync
  class Migration
    include ::KintoneSync::Base
    def copy_column from_name, to_name
      fields={}
      kintone.api.form.get(@app_id)['properties'].each do |field|
        next unless field['code'] == from_name
        options = {}
        field['options'].each_with_index do |option, i|
          options[option] = {label: option, index: i}
        end
        fields[to_name] = {
          type: field['type'],
          code: to_name,
          label: field['label'],
          options: options
        }
      end
      kintone.set_fields fields
      kintone.deploy
      kintone.all.each do |record|
        id = record['$id']['value'].to_i
        params = {}
        params[to_name] = record[from_name]['value']
        update id, params
      end
    end

    def rename_column before_name, after_name
      copy_column before_name, after_name
      drop_column before_name
    end

    def tranfer_data from_name, to_name

    end

    def drop_column name

    end

    def change_column name, type
      before_name = name
      after_name = "_#{name}"
      copy_column before_name, after_name
      tranfer_data before_name, after_name
      drop_column before_name
    end
  end
end
