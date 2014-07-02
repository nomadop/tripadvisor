# encoding: utf-8

class Youdao
	
	def self.get_conn
		conn = Conn.init('http://fanyi.youdao.com')
		response = conn.get('/')
		conn.headers['cookie'] = response.headers['set-cookie']
		conn.params = {
			smartresult: 'dict',
			sessionFrom: 'null'
		}
		return conn
	end

	def self.translate src_str
		conn = get_conn
		response = conn.post '/translate', {
			type: 'AUTO',
			i: src_str,
			doctype: 'json',
			xmlVersion: 1.6,
			keyfrom: 'fanyi.web',
			ue: 'UTF-8',
			typoResult: true
		}
		result = JSON.parse(response.body)
		if result['smartResult']
			result['smartResult']['entries'].delete_if{|s| s.blank?}[0]
		else
			result['translateResult'][0][0]['tgt']
		end
	end

end