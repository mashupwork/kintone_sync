module KintoneSync
  class Migration
    include ::KintoneSync::Base
    def rename_column before_name, after_name
      fields={
        app: @app_id,
        properties: {}
      }

      kintone.api.form.get(@app_id)['properties'].each do |field|
        next unless field['code'] == before_name
        fields['properties'][after_name] = {
          type: field['type'],
          code: after_name,
          label: field['label'],
          options: field['options']
        }
      end
      kintone.set_fields fields
      kintone.deploy
      
      kintone.all.each do |record|
        id = record['$id']['value'].to_i
        params = {}
        params[after_name] = record[before_name]['value']
        update id, params
      end
    end

    def change_column name, type
      fields={}
      fields[name] = {
        type: type,
        code: name
      }
      kintone.update_fields(app_id, fields)
      kintone.deploy(app_id)
    end
  end
end
