module KintoneSync
  class Kintone
    attr_accessor :app_id
    def initialize(app_id=nil, params = {})
      @host = params[:host] || ENV['KINTONE_HOST']
      @user = params[:user] || ENV['KINTONE_USER']
      @pass = params[:pass] || ENV['KINTONE_PASS']

      # https://github.com/jue58/kintone/compare/master...pandeiro245:basic-auth
      @basic_user = ENV['KINTONE_BASIC_USER']
      @basic_pass = ENV['KINTONE_BASIC_PASS']

      @app_id = app_id.to_i
      if @basic_user
        @api = ::Kintone::Api.new(
          @host, @user, @pass,
          @basic_user, @basic_pass
        )
      else
        @api = ::Kintone::Api.new(
          @host, @user, @pass
        )
      end
      @info = info
      @fields = fields
    end

    def apps
      url = '/k/v1/apps.json'
      #res = @api.get(url, {app: self.app_id})
      res = @api.get(url)
      return res
    end

    def properties
      @fields['properties']
    end

    def fields
      unless @fields
        url = '/k/v1/app/form/fields.json'
        @fields = @api.get(url, {app: self.app_id})
      end
      @fields
    end

    def info
      unless @info
        url = '/k/v1/preview/app/settings.json'
        @info = @api.get(url, {app: self.app_id})
      end
      @info
    end

    def backup_all
      apps['apps'].each do |app|
        app_id = app['appId']
        backup_id = ENV['KINTONE_BACKUP']
        next if app_id.to_i == backup_id.to_i
        k= KintoneSync::Kintone.new(app_id)
        puts "start to backup #{app_id}"
        k.backup
        puts "end to backup #{app_id}"
      end
    end

    def backup
      backup_id = ENV['KINTONE_BACKUP']
      self.class.new(backup_id).create({
        appName: info['name'],
        appId: app_id.to_i,
        structure: fields.to_json,
        data: all.to_json # TODO 複数文字列カラムの容量制限確認
      })
    end

    def self.app_create!(name, fields=nil, kintone=nil)
      kintone ||= self.new
      @api = kintone.api
      url = '/k/v1/preview/app.json'
      res = @api.post(url, name:name)
      app = res['app'].to_i
      kintone.app(app).create_fields(fields) if fields
      kintone.deploy
      return {app: app, name: name}
    end

    def create_fields fields
      puts 'create_fields in KintoneSync::Kintone'
      url = '/k/v1/preview/app/form/fields.json'
      params = {app: @app_id, properties: fields}

      res = @api.post(url, params)
      puts res.inspect
      raise res['errors'] if res['errors']
    end

    def update_fields fields
      url = '/k/v1/preview/app/form/fields.json'
      params = {app: @app_id, properties: fields}

      res = @api.put(url, params)
      puts res.inspect
      raise if res['errors']
    end

    def delete_field field_name
      url = '/k/v1/preview/app/form/fields.json'
      params = {app: @app_id, fields: [field_name]}
      res = @api.delete(url, params)
      puts res.inspect
      raise if res['errors']
      res
    end

    def deploy
      sec = 5
      url = '/k/v1/preview/app/deploy.json'
      res = @api.post(url, apps:[{app: @app_id}])

      if res['code'] && res['code'] == 'GAIA_APD02'
        # 設定を運用環境に適用する処理、または設定をキャンセルする処理をすでに実行中です。
        puts  "sleep #{sec}sec..."
        sleep sec
        deploy
      end
      raise res.inspect if res['errors']
      puts "deploy is done! & sleep #{sec}sec..."
      sleep sec

      res
    end

    def self.remove(app_id)
      self.new(app_id).remove
    end

    def api
      @api
    end

    def find id
      @api.record.get(@app_id, id)['record']
    end

    def app(app_id)
      @app_id = app_id
      self
    end

    def all
      res = []
      offset = 0
      query = "offset #{offset}"
      items = @api.records.get(@app_id, query, [])
      while(items['records'].present?)
        res += items['records']
        offset += items['records'].count
        query = "offset #{offset}"
        items = @api.records.get(@app_id, query, [])
      end
      res
    end

    def limit(limit=0) # FIXME
      query = "offset 0"
      @api.records.get(@app_id, query, [])['records']
    end

    def where cond
      query = ''
      cond.each do |k, v|
        query += ' and ' unless query == ''
        if properties[k.to_s]['type'] == 'DROP_DOWN'
          query += "#{k} in (\"#{v}\")"
        else
          query += "#{k} = \"#{v.to_s}\""
        end
      end
      @api.records.get(@app_id, query, [])
    end

    def save pre_params, unique_key=nil
      if unique_key
        cond = {}
        cond[unique_key] = pre_params[unique_key]
        records = where(cond)['records']
        if records.present?
          id = records.first['$id']['value'].to_i
          return update(id, pre_params)
        end
      end
      create(pre_params)
    end

    def create pre_params
      params = {}
      pre_params.each do |k, v|
        params[k] = {value: v}
      end
      begin
        res = @api.record.register(@app_id, params)
      rescue
        #sleep 5
        sleep 0.1
        save pre_params
      end
      res
    end

    def create! pre_params
      res = create(pre_params)
      res['message'] ? raise(res.inspect) : res
    end

    def save! record, unique_key=nil
      res = save(record, unique_key)
      res['message'] ? raise(res.inspect) : res
    end

    def update id, record
      params = {}
      record.each do |k, v|
        params[k] = {value: v}
      end
      @api.record.update(@app_id, id.to_i, params) 
    end

    def create_all records
      array = []
      records.each do |r|
        params = {}
        r.each do |k, v|
          params[k] = {value: v}
        end
        array.push(
          params
        )
      end
      puts "create #{array.count} records..."
      while array.present?
        a100 = array.shift(100)
        res = @api.records.register(@app_id, a100) 
      end
      {}
    end

    def update_all records
      array = []
      records.each do |id, r|
        params = {}
        r.each do |k, v|
          params[k] = {value: v}
        end
        array.push({
          id: id,
          record: params
        })
      end
      puts "update #{array.count} records..."
      while array.present?
        a100 = array.shift(100)
        @api.records.update(@app_id, a100) 
      end
      {}
    end
    def create_all! records
      res = create_all(records)
      res['message'] ? raise(res.inspect) : res
    end

    def update! id, record
      res = update(id, record)
      res['message'] ? raise(res.inspect) : res
    end

    def update_all! records
      res = update_all(records)
      res['message'] ? raise(res.inspect) : res
    end

    def remove app_id=nil
      app_id ||= @app_id
      # データ取得：上限500件
      # データ削除：上限100件
      query = 'limit 100' 
      records = @api.records.get(app_id, query, [])['records']
      is_retry = true if records.present? && records.count >= 100
      return 'no records' if records.blank?
      ids = records.map{|r| r['$id']['value'].to_i}
      puts 'start to delete'
      @api.records.delete(app_id, ids)
      puts 'end to delete'
      remove app_id if is_retry
    end
  end
end
