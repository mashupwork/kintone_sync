module KintoneSync
  class Kintone
    attr_accessor :app_id
    def initialize(app_id=nil, params = {})
      @host = params[:host] || ENV['KINTONE_HOST']
      @user = params[:user] || ENV['KINTONE_USER']
      @pass = params[:pass] || ENV['KINTONE_PASS']

      # https://github.com/jue58/kintone/compare/master...pandeiro245:basic-auth
      @basic_user = params[:basic_user] || ENV['KINTONE_BASIC_USER']
      @basic_pass = params[:basic_pass] || ENV['KINTONE_BASIC_PASS']

      @fields_cache = {}

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
      info
      fields
    end

    def apps
      url = '/k/v1/apps.json'
      #res = @api.get(url, {app: self.app_id})
      res = @api.get(url)
      return res
    end

    def properties
      fields['properties']
    end

    def fields
      unless @fields_cache[app_id]
        url = '/k/v1/app/form/fields.json'
        @fields_cache[app_id] = @api.get(url, {app: self.app_id})
      end
      @fields_cache[app_id]
    end

    def fetch_views
      url = '/k/v1/preview/app/views.json'
      @api.get(url, {app: self.app_id})
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
      raise res['errors'].inspect if res['errors']
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
      fetch_records('', fetch_all: true)
    end

    def container_type?(type)
      %w(DROP_DOWN CHECK_BOX RADIO_BUTTON).include?(type)
    end

    def where(cond_or_query, options = {})
      query = cond_or_query.is_a?(String) ? cond_or_query : where_query(cond_or_query, options)
      fetch_records(query)
    end

    def where_query(cond, options = {})
      query = ''.dup
      cond.each do |k, v|
        query << ' and ' unless query == ''
        type = properties[k.to_s]['type']
        is_container = container_type?(type)
        not_op = is_container ? 'not' : ?! if options[:not]
        query << if container_type?(type)
                   if v.is_a?(Array)
                     "#{k} #{not_op} in (\"#{v.join('","')}\")"
                   else
                     "#{k} #{not_op} in (\"#{v}\")"
                   end
                 else
                   "#{k} #{not_op}= \"#{v}\""
                 end
      end
      if options[:order_by]
        query << " order by #{options[:order_by]}"
      end
      query
    end

    def find_by(cond, options = {})
      base_query = where_query(cond, options)
      query = "#{base_query} limit 1 offset 0"
      @api.records.get(@app_id, query, [])['records'].first
    end

    def find_each(cond, options = {})
      where(cond, options).each
    end

    def save pre_params, unique_key=nil
      if unique_key
        cond = {}
        cond[unique_key] = pre_params[unique_key]
        records = where(cond)
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
      @api.record.register(@app_id, params)
    end

    def create! pre_params
      res = create(pre_params)
      res['message'] ? raise(res.inspect) : res
    end

    def save! record, unique_key=nil
      res = save(record, unique_key)
      res['message'] ? raise(res.inspect) : res
    end

    def update id, record, revision: nil
      params = {}
      record.each do |k, v|
        params[k] = {value: v}
      end
      @api.record.update(@app_id, id.to_i, params, revision: revision)
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
      res
    end

    # records = [[record_id, params], [record_id, params], ....]
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

    def update! id, record, revision: nil
      res = update(id, record, revision: revision)
      res['message'] ? raise(res.inspect) : res
    end

    def update_all! records
      res = update_all(records)
      res['message'] ? raise(res.inspect) : res
    end

    def remove app_id=nil, revisions: nil
      app_id ||= @app_id
      # データ取得：上限500件
      # データ削除：上限100件
      query = 'limit 100'
      records = @api.records.get(app_id, query, [])['records']
      is_retry = true if records.present? && records.count >= 100
      return 'no records' if records.blank?
      ids = records.map{|r| r['$id']['value'].to_i}
      puts 'start to delete'
      @api.records.delete(app_id, ids, revisions: revisions)
      puts 'end to delete'
      remove app_id if is_retry
    end

    private

    def fetch_records(base_query = '', fetch_all: false)
      # for more than 10,000 records.
      # https://developer.cybozu.io/hc/ja/articles/360030757312#use_id

      res = []
      offset = 0
      limit = 500
      previous_id = 0
      loop do
        query = if fetch_all
                  "$id > #{previous_id} order by $id asc limit 500"
                else
                  "#{base_query} limit #{limit} offset #{offset}"
                end
        records = @api.records.get(@app_id, query, []).dig('records')
        break unless records

        res += records

        if fetch_all
          last_record_id = records.last.dig('$id', 'value')
          break if previous_id == last_record_id

          previous_id = last_record_id
        else
          break if records.count < limit

          offset += limit
        end
      end

      res
    end

    alias_method :fetch_all_records, :fetch_records
  end
end
