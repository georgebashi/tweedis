#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"

require 'sinatra'
require 'haml'
require 'sinatra/content_for'

load "model.rb"
load "basic_auth.rb"

$redis = Redis.new

before do
  check_auth do |username, password|
    @user = User.load username
    @logged_in = sha1(password) == @user.password
  end
end

get '/' do
  if !logged_in?
    haml :welcome
  else
    haml :home
  end
end

get '/user/:username' do
  @profile = User.load params['username']
  haml :profile
end

get '/user/:username/followers' do
  @title = "#{params['username']}'s followers"
  @users = User.load(params['username']).followers
  haml :userlist
end

get '/user/:username/following' do
  @title = "Users #{params['username']} is following"
  @users = User.load(params['username']).following
  haml :userlist
end

post '/user/:username/follow' do
  @user.follow params['username']
  redirect "/user/#{params['username']}"
end

get '/login' do
  return_401 if !logged_in?
  redirect '/'
end

post '/post' do
  return_401 if !logged_in?

  Status.create @user, params['status']
  redirect '/'
end

post '/signup' do
  User.create params['username'], params['password']
  redirect '/'
end

get '/logout' do
  return_401
end
