class JobConfig < ActiveRecord::Base
  def config=(config)
    self.config_json = config if has_attribute?(:config_json)
    super
  rescue Encoding::UndefinedConversionError
  end
end

class Job < ActiveRecord::Base
  class << self
    SQL = {
      queueable: 'RIGHT JOIN queueable_jobs on queueable_jobs.job_id = jobs.id'
    }

    def queueable
      # sets jobs order based on priority first, ie: 5, nil, -5
      jobs = where(state: :created).order("COALESCE(priority, 0) desc").order(:id)
      jobs = jobs.joins(SQL[:queueable]).order(:id) if ENV['USE_QUEUEABLE_JOBS']
      jobs
    end

    def running
      where(state: [:queued, :received, :started]).order('jobs.id')
    end

    def private
      where(private: true)
    end

    def public
      where('jobs.private IS NULL OR jobs.private = ?', false)
    end

    def by_repo(id)
      where(repository_id: id)
    end

    def by_owners(owners)
      where(owned_by(owners))
    end

    def by_queue(queue)
      where(queue: queue)
    end

    def owned_by(owners)
      owners.map { |o| owner_id.eq(o.id).and(owner_type.eq(o.class.name)) }.inject(&:or)
    end

    def owner_id
      arel_table[:owner_id]
    end

    def owner_type
      arel_table[:owner_type]
    end
  end

  FINISHED_STATES = [:passed, :failed, :errored, :canceled]

  self.inheritance_column = :_disabled

  belongs_to :repository
  belongs_to :commit
  belongs_to :source, polymorphic: true, autosave: true
  belongs_to :owner, polymorphic: true
  belongs_to :stage
  belongs_to :config, foreign_key: :config_id, class_name: JobConfig
  has_one :queueable

  serialize :config
  serialize :debug_options

  def finished?
    FINISHED_STATES.include?(state.try(:to_sym))
  end

  def queueable=(value)
    if value
      queueable || create_queueable
    else
      Queueable.where(job_id: id).delete_all
    end
  end

  def public?
    !private?
  end

  def config
    record = super
    config = record&.config_json if record.respond_to?(:config_json) # TODO remove once we've rolled over
    config ||= record&.config
    config ||= read_attribute(:config) if has_attribute?(:config)
    config ||= {}
    config.deep_symbolize_keys!
  end

  def name
    config[:name]
  end
end
