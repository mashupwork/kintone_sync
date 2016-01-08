module KintoneSync
  module Base
    include ::KintoneSync::Utils
    def initialize app_id=nil
      @client = new_client
      @token = get 'token'
      @app_id = app_id
      @kintone = Kintone.new(app_id)
    end

    def new_client
      return nil unless self.class.method_defined?(:setting)
      setting = self.setting
      upcase = self.class.to_s.upcase.split('::').last
      @client = ::OAuth2::Client.new(
        ENV["#{upcase}_KEY"],
        ENV["#{upcase}_SECRET"],
        site: setting[:site],
        #authorize_url: setting[:authorize_url],
        #token_url: setting[:token_url],
        #ssl: { verify: false }
      )
    end

    def kintone
      @kintone ||= Kintone.new(@app_id)
      @kintone
    end

    def access_token
      OAuth2::AccessToken.new(@client, @token)
    end

    def kintone_loop(model_name, params={})
      @kintone ||= create_app!(model_name)

      #if self.class == Facebook
      #  data = self.send(model_name, params)
      #  items = data['data']
      #  next_page = data['paging']['next']
      #else
      #  items = self.send(model_name, params)
      #end
      items = self.send(model_name, params)

      while items.present?
        items.each_with_index do |item, i|
          record = item2record(item)
          name = item['name'] || item['title'] || item['description'] || item['id'] || '名称不明'
          puts "#{i}: saving #{name}"
          app_id = get "kintone_app_#{model_name.downcase}"
          @kintone.app(app_id).save(record)
        end
        params[:page] ||= 1
        params[:offset] ||= 0
        params[:page] += 1 if params[:page]
        params[:offset] += items.count if params[:offset]
        return if params[:is_all]
        #if next_page
        #  data = fetch(next_page)
        #  items = data['data']
        #  #next_page = data['paging'].present? ? data['paging']['next'] : nil
        #elsif self.class == Twitter
        #  # do nothing
        #else
        #  items = self.send(model_name, params)
        #end
        items = self.send(model_name, params)
      end
    end

    def item2record item
      record = {}
      item.to_hash.each do |key, val|
        begin
          if val.class == Hash
            val.each do |k, v|
              record["#{key}_#{k}"] = typed_val(k, v)
            end
          else
            record[key] = typed_val(key, val)
          end
        rescue=>e
          puts "key is below"
          puts key.inspect
          puts val.inspect
          raise e.inspect
        end
      end
      record
    end

    def typed_val key, val
      if key.match(/_at$/)
        if val.to_i > 0 # timecrowd
          val = Time.at(val.to_i)
        elsif !val.nil?
          val = val.to_datetime
        end
      elsif key.match(/_time$/) # facebook
        val = val.to_datetime
      elsif key.match(/^is_/)
        val = val == true ? 1 : 0
      end
      val
    end

    def item2type key, val
      if key.match(/_at$/) || key.match(/_time$/)
        'DATETIME'
      elsif key.match(/_on$/) || key == 'date'
        'DATE'
      elsif !key.match(/id$/) && (val.class == Fixnum || key == 'duration') # idを数値にするとtweet_idなどが桁数オーバーするので文字列にする
        'NUMBER'
      else
        'SINGLE_LINE_TEXT'
      end
    end

    def item2field_names item
      res = {}
      item.to_hash.each do |key, val|
        if val.class == Hash
          val.each do |k, v|
            key2 = "#{key}_#{k}"
            res[key2] = {
              code: key2,
              label: key2,
              type: item2type(k, v)
            }
          end
        else
          res[key] = {
            code: key, 
            label: key, 
            type: item2type(key, val)
          }
          res[key][:unique] = true if key.to_sym == :id
        end
      end
      res 
    end

    def sync(refresh=false)
      model_names.each do |model_name|
        key = model_name.underscore.pluralize
        kintone_key = "kintone_app_#{key}"
        id = self.get kintone_key
        self.remove(id) if refresh
        unless self.exist?("kintone_app_#{model_name.underscore.pluralize}")
          id = KintoneSync::Kintone.app_create!(
            "#{self.class.to_s.split('::').last}::#{model_name}", 
            field_names(model_name)
          )[:app]
          self.set kintone_key, id
        end
        self.sync_a_model(model_name)
      end
    end

    def sync_a_model model_name
      if self.class.instance_methods.include?(:sync_a_model)
        kintone_loop(model_name.underscore.pluralize)
      else
        super
      end
    end

    def remove(id)
      KintoneSync::Kintone.new(id).remove
    end

    def client
      @client
    end

    def fetch url
      begin
        puts "url is #{url}"
        access_token.get(url).parsed
      rescue=>e
        raise e.inspect
        sleep 5
        fetch url
      end
    end

    def create_app! model_name
      key = model_name.underscore.pluralize
      KintoneSync::Kintone.new(
        get("kintone_app_#{key}")
      ) 
    end

    def field_names model_name
      key = model_name.underscore.pluralize
      #items = eval("#{self.class.to_s}.new.#{key}")
      items = self.send(key)
      #items = items['data'] if self.class == Facebook
      return nil unless items.present?
      item = items.first
      item2field_names(item)
    end
  end
end
