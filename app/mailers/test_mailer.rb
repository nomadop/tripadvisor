class TestMailer < ActionMailer::Base
  default from: "lottery@senscape.com.cn"

  def mymail to, subject, send_at = Time.now
  	@send_on = send_at
  	mail(
  		to: to,
  		subject: subject
  	)
  end
end
