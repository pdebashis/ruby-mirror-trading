# smtp_cfg = YAML.load_file("#{Dir.pwd}/config/config.yml")

# smtp_server="smtp-relay.brevo.com"
# smtp_port=587
# smtp_username=
# smtp_password=

# message = <<~NOTIFY
#   From: ruby-mirror-trading@nexttrade
#   To: #{smtp_username}
#   Subject: Ruby-Mirror Trading is now running

#   This is the body
# NOTIFY

# smtp = Net::SMTP.new(smtp_server, smtp_port)
# smtp.enable_starttls
# smtp.start(smtp_server, smtp_username, smtp_password, :login) do |smtp|
#   smtp.send_message(message, 'ruby-mirror-trading@nexttrade', smtp_username)
# end