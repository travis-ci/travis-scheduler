require 'active_record'
require 'travis/scheduler/models/organization'
require 'travis/scheduler/models/ssl_key'
require 'travis/scheduler/models/user'

class Repository < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
  has_one    :key, class_name: :SslKey

  def slug
    @slug ||= [owner_name, name].join('/')
  end

  def api_url
    "#{Travis.config.github.api_url}/repos/#{slug}"
  end

  def source_url
    (private? || private_mode?) ? "git@#{source_host}:#{slug}.git": "git://#{source_host}/#{slug}.git"
  end

  def private_mode?
    source_host != 'github.com'
  end

  def source_host
    Travis.config.github.source_host || 'github.com'
  end

  def settings
    @settings ||= Repository::Settings.load(super, repository_id: id).tap do |settings|
      settings.on_save do
        self.settings = settings.to_json
        self.save!
      end
    end
  end
end

require 'travis/scheduler/models/repository/settings'
