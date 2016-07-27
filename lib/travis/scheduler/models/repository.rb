require 'active_record'
require 'travis/scheduler/models/organization'
require 'travis/scheduler/models/permission'
require 'travis/scheduler/models/ssl_key'
require 'travis/scheduler/models/user'

class Repository < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
  has_one    :key, class_name: :SslKey

  has_many :permissions
  has_many :users, :through => :permissions

  def slug
    @slug ||= [owner_name, name].join('/')
  end

  def public?
    !self.private?
  end

  def api_url
    "#{Travis.config.github.api_url}/repos/#{slug}"
  end

  def source_url
    ( private? || force_private? || admin.nil? ) && !Travis.config.prefer_https ? "git@#{source_host}:#{slug}.git": "https://#{source_host}/#{slug}.git"
  end

  def force_private?
    source_host != 'github.com'
  end

  def source_host
    Travis.config.github.source_host || 'github.com'
  end

  def settings
    @settings ||= Repository::Settings.load(super, repository_id: id)
  end

  def admin
    candicates = User.with_github_token.with_permissions(:repository_id => id, :admin => true).first
    admin = candicates.first

    admin || begin
      Travis.logger.error("[github-scheduler] repository #{slug} does not have admin")
      nil
    end
  rescue
    nil
  end
end

require 'travis/scheduler/models/repository/settings'
