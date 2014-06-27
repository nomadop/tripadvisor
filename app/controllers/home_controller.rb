class HomeController < ApplicationController
  def index
  end

  def test_faye
  	broadcast("/messages/new", "hollw")

  	render :text => ''
  end

  def send_mail
  	mail = TestMailer.mymail('nomadop@gmail.com', 'test')
  	mail.deliver
    render :text => 'Message sent successfully'  
  end
end
