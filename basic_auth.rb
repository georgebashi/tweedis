helpers do
  def return_401
    response['WWW-Authenticate'] = %(Basic realm="Tweedis")
    throw(:halt, [401, "Not authorized\n"])
  end
  
  def logged_in?
    @logged_in
  end
  
  def check_auth
    @logged_in = false

    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    return if !@auth.provided?

    yield *@auth.credentials 
  end
end