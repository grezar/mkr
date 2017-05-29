require 'sinatra'
require_relative 'lib/mkr'

class App < Sinatra::Base
  ACTIONS = {
    entered: :punch_in,
    exited: :punch_out
  }.freeze

  post '/' do
    params = JSON.parse(request.body.read)
    action = ACTIONS.fetch(params['action'].to_sym)

    Mkr.logger.info("Process `:#{action}` action")
    unless valid?(action)
      Mkr.logger.failure("Invalid action: `:#{action}`")
      return
    end

    begin
      user = User.from_env
      Mkr.run(user, action)
      Mkr.logger.success("Process `:#{action}` action")
      Notifier.success(user.name, action)
    rescue => e
      Mkr.logger.failure(e.message, e)
      Notifier.failure(user.name, action, e)
      raise e
    end
  end

  private

  def valid?(action)
    validate_action(action) &&
      send("validate_#{action}")
  end

  def validate_action(action)
    ACTIONS.values.include?(action)
  end

  def validate_punch_in
    now = Time.now
    now < Time.local(now.year, now.month, now.day, 15, 0)
  end

  def validate_punch_out
    now = Time.now
    Time.local(now.year, now.month, now.day, 15, 0) <= now
  end
end
