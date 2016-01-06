module KintoneSync
  class Freee
    def self.setting
      {
        site: 'https://api.freee.co.jp/',
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token',
        model_names: ['Walletable', 'WalletTxn']
      }
    end

    def sync model_name
      case model_name
      when 'WalletTxn'
        kntn_loop('wallet_txns', {offset: 0})
      when 'Walletable'
        kntn_loop('walletables', {is_all: true})
      end
    end

    def wallet_txns(params={})
      offset = params[:offset] || 0
      url = "/api/1/wallet_txns.json?company_id=#{company_id}&offset=#{offset}"
      res = fetch(url)
      res['wallet_txns'].map do |i|
        i2 = i
        i.keys.each do |column_name|
          val = i[column_name]
          val = val * (-1) if column_name.match(/amount/) && i['entry_side'] == 'expense'
          i2[column_name] = val
        end
        i2
      end
    end

    def walletables prams = {}
      fetch("/api/1/walletables.json?company_id=#{company_id}")['walletables']
    end

    def company_id
      url = '/api/1/users/me?companies=true'
      fetch(url)['user']['companies'].first['id'].to_i
    end    
  end
end
