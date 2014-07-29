# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

ENV['PID'] ="2088011685125151"
ENV['KEY'] = "od2qjazaunh38cnapa28axtl212nqo1o"
ENV['EMAIL'] = "hr@senscape.com.cn"
ENV["host"] = "http://asia.senscape.com.cn"
ENV['token'] = 'IP0aYE3uhnqnxU09wx4faba06b388159'
ENV['WechatAppId'] = 'wx4faba06b3881580c'
ENV['WechatAppSecret'] = '756b560bb906ed46ae600cb98c0a1137'

ENV['push_server_url'] = 'http://112.64.16.22:8081/mc/ios/push_one'
ENV['push_android_server_url'] = 'http://112.64.16.22:8081/mc/android/push_one'
ENV['android_appkey'] = 'a4aaa8bbca39238e0d8e2751'

require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
