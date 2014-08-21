# encoding: utf-8

module Taobao
	class Connection
		attr_reader :broser, :doc, :item_id, :sku_id, :seller_id, :site_id, :size_names, :color_names
		attr_accessor :username, :password, :item_url

		def initialize username = nil, password = nil
			@username = username
			@password = password
			@broser = Watir::Browser.new :firefox
			@broser.goto('http://www.taobao.com')
		end

		def login
			return false if username == nil || password = nil
			@broser.div(id: 'J_LoginInfoHd').a.click
			@broser.text_field(name: 'TPL_username').set(username)
			@broser.text_field(name: 'TPL_password').set(password)
			@broser.button(id: 'J_SubmitStatic').click
		end

		def get_item_info
			return false if @item_url == nil
			@broser.goto(@item_url)
			# @doc = Nokogiri::HTML(@broser.html)
			response = Faraday.new('').get(@item_url)
			@doc = Nokogiri::HTML(response.body)

			@item_id = @doc.to_s.match(/item_id=(\d+)/)[1]
			@seller_id = @doc.to_s.match(/seller_id_num=(\d+)/)[1]
			@site_id = @doc.to_s.match(/siteID=(\d+)/)[1]

			size_selects = @doc.css('ul.J_TSaleProp[data-property="尺码"]')
			@size_names = size_selects.css('li').map{|li| li.css('span')[0].content }
			color_selects = @doc.css('ul.J_TSaleProp[data-property="颜色分类"]')
			@color_names = color_selects.css('li').map{|li| li.css('span')[0].content }

			sku_map = @doc.to_s.gsub(/[ |\n|\t|\r]/, '').match(/"skuMap":(\{(.*?)\})\);/)[1]
			@sku_map = JSON.parse(sku_map[0...-2])
			item_info
		end

		def get_sku_id size_name, color_name
			size_selects = @doc.css('ul.J_TSaleProp[data-property="尺码"]')
			color_selects = @doc.css('ul.J_TSaleProp[data-property="颜色分类"]')

			size_id = size_selects.css('li').select{|li| li.css('span')[0].content == size_name}[0]['data-value']
			color_id = color_selects.css('li').select{|li| li.css('span')[0].content == color_name}[0]['data-value']

			sku_query_str = ";#{size_id};#{color_id};"
			@sku_id = @sku_map[sku_query_str]['skuId']
		end

		def buy_now
			return false if sku_id == nil
			params = {
				item_id: item_id,
				item_id_num: item_id,
				auction_type: 'b',
				from: 'item_detail',
				quantity: 1,
				skuId: sku_id
			}
			@broser.goto("http://buy.taobao.com/auction/buy_now.jhtml?#{params.to_param}")

			@doc = Nokogiri::HTML(@broser.html)

			form = doc.css('form[name=J_Form]')[0]
			params = form.css('input[type=hidden], input[type=text]').inject({}) do |res, i| 
				res[i['name']] = i['value'] unless i['name'].blank?
				res
			end
		end

		def try_buy params
			begin
				@broser.execute_script("if (typeof window.jQuery == 'undefined') {var fileref = document.createElement('script');fileref.setAttribute('type', 'text/javascript');fileref.setAttribute('src', 'http://code.jquery.com/jquery-latest.js');if (typeof fileref != 'undefined') {document.getElementsByTagName('head')[0].appendChild(fileref);}}")
			rescue Exception => e
				p e
			end
			begin
				@broser.execute_script("var params = jQuery.parseJSON('#{params.to_json}');console.log(params);jQuery.post('http://buy.taobao.com/auction/order/unity_order_confirm.htm', params);")
			rescue Exception => e
				p e
			end
		end

		def item_info
			{ item_id: item_id, color_names: color_names, size_names: size_names, seller_id: seller_id, site_id: site_id }
		end

		def makeup_cookie_str
			cookies = @broser.cookies.to_a
			cookies.map{|c| "#{c[:name]}=#{c[:value]}"}.join('; ')
		end
	end
end