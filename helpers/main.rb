require 'json'

module CommonHelper
  # Parse of JSON request
  def to_hash(json_data)
    JSON.parse(json_data)
  end

  # Method name explain everything
  def login_exists?(options = {})
    User.first(login: options['login']).nil? ? false : true
  end
end
