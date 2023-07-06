# frozen_string_literal: true

# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
#
# Copyright (c) 2018 BigBlueButton Inc. and by respective authors (see below).
#
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

class HealthCheckController < ApplicationController
  skip_before_action :redirect_to_https, :set_user_domain, :set_user_settings, :maintenance_mode?, :migration_error?,
                     :user_locale, :check_admin_password, :check_user_role

  def groups
    token = nil
    group = nil

    unless token
      request.query_parameters.each do |key, value|
        if key == 'token'
          token = value
        end
        if key == 'group'
          group = value
        end
      end
    end

    puts token

    if token
      response = HTTParty.get(ENV["VZNANIYA_URL"] + "/api/v2/profile",
                              :headers => {
                                'Content-Type' => 'application/json',
                                'Authorization' => token
                              }
      )

      puts ENV["VZNANIYA_URL"] + "/api/v2/profile"
      puts response.headers['content-type']

      if response.headers['content-type'] != "text/html; charset=UTF-8"

        data = JSON.parse(response.body, object_class: OpenStruct)
        user = User.includes(:role, :main_room).find_by(external_id: data.data.id)

        puts user

        if user and data.data.role == 'teacher'
          groups_res = HTTParty.get(ENV["VZNANIYA_URL"] + "/api/v2/groups/filter",
                                    :headers => {
                                      'Content-Type' => 'application/json',
                                      'Authorization' => token
                                    }
          )

          puts ENV["VZNANIYA_URL"] + "/api/v2/groups/filter"

          groups = JSON.parse(groups_res.body, object_class: OpenStruct).data
          groups.each_with_index { |group, index|
            unless Room.exists?(:external_id => group.id)
              room = Room.create(:user_id => user.id, :name => group.name, :deleted => false, :created_at => Time.now.getutc, :updated_at => Time.now.getutc, :external_id => group.id)
              room.save(:validate => false)
            end
          }
        end
      end
    end

    render plain: "success"
  end

  # GET /link
  def link
    group = nil

    unless group
      request.query_parameters.each do |key, value|
        if key == 'group'
          group = value
        end
      end
    end

    unless group.nil?
      room = Room.find_by(external_id: group)
      if room
        return '/b/' + room.uid
      end
    end
  end

  # GET /health_check
  def all
    response = "success"
    @cache_expire = 10.seconds

    begin
      cache_check
      database_check
      email_check
    rescue => e
      response = "Health Check Failure: #{e}"
    end

    render plain: response
  end

  private

  def cache_check
    if Rails.cache.write("__health_check_cache_write__", "true", expires_in: @cache_expire)
      raise "Unable to read from cache" unless Rails.cache.read("__health_check_cache_write__") == "true"
    else
      raise "Unable to write to cache"
    end
  end

  def database_check
    raise "Database not responding" if defined?(ActiveRecord) && !ActiveRecord::Migrator.current_version
    raise "Pending migrations" unless ActiveRecord::Migration.check_pending!.nil?
  end

  def email_check
    test_smtp if Rails.configuration.action_mailer.delivery_method == :smtp
  end

  def test_smtp
    settings = ActionMailer::Base.smtp_settings

    smtp = Net::SMTP.new(settings[:address], settings[:port])
    smtp.enable_starttls_auto if settings[:enable_starttls_auto] == ("true") && smtp.respond_to?(:enable_starttls_auto)

    if settings[:authentication].present? && settings[:authentication] != "none"
      smtp.start(settings[:domain]) do |s|
        s.authenticate(settings[:user_name], settings[:password], settings[:authentication])
      end
    else
      smtp.start(settings[:domain])
    end
  rescue => e
    raise "Unable to connect to SMTP Server - #{e}"
  end
end
