require 'sinatra'
require 'date'
require 'holiday_jp'
require_relative 'lib/mkr'

class App < Sinatra::Base
  IFTTT_ACTIONS = {
    'entered' => :punch_in,
    'exited'  => :punch_out
  }.freeze

  SATURDAY = 6
  SUNDAY = 0

  post '/' do
    params = JSON.parse(request.body.read)
    action = IFTTT_ACTIONS[params['action']]
    today = Date.today

    unless valid_action?(action)
      Mkr.logger.failure("Invalid parameters: #{params.inspect}")
      return
    end

    unless valid_clock?(action)
      Mkr.logger.failure("Off hour: `:#{action}`")
      raise "Off hour: `:#{action}`"
    end

    unless valid_workday?(today)
      Mkr.logger.failure("Day off: `#{today}`")
      raise "Day off: `:#{today}`"
    end

    Mkr.logger.info("Process `:#{action}` action")
    begin
      user = Mkr::User.from_env
      Mkr.run(user, action)
      Mkr.logger.success("Process `:#{action}` action")
      Mkr::Notifier.success(user.name, action)
    rescue => e
      Mkr.logger.failure(e)
      Mkr::Notifier.failure(user.name, action, e)
      raise e
    end
  end

  private

  def valid_action?(action)
    IFTTT_ACTIONS.values.include?(action)
  end

  def valid_clock?(action)
    send("validate_#{action}")
  end

  def valid_workday?(day)
    !([SATURDAY, SUNDAY].include?(day.wday) || HolidayJp.holiday?(day))
  end

  def validate_punch_in
    now = Time.now
    now < Time.local(now.year, now.month, now.day, 10, 30)
  end

  def validate_punch_out
    now = Time.now
    Time.local(now.year, now.month, now.day, 16, 0) <= now
  end
end
