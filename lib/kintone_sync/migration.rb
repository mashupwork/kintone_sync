module KintoneSync
  class Migration
    def rename_column app_id, before_name, after_name
      fields={}
      fields[before_name] = {
        type: 'DROP_DOWN',
        code: after_name
      }
      k = Kintone.new(app_id)
      k.set_fields(app_id, fields)
      k.deploy(app_id)
    end

    def change_column app_id, name, type
      fields={}
      fields[name] = {
        type: type,
        code: name
      }
      k = Kintone.new(app_id)
      k.set_fields(app_id, fields)
      k.deploy(app_id)
    end
  end
end
