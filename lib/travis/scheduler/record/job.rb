class Job < ActiveRecord::Base
  class << self
    SQL = {
      queueable: 'RIGHT JOIN queueable_jobs on queueable_jobs.job_id = jobs.id'
    }

    def queueable
      jobs = joins(SQL[:queueable]).order(:id)
      jobs = jobs.where(state: :created).order(:id) if ENV['USE_JOB_STATE']
      jobs
    end

    def running
      where(state: [:queued, :received, :started]).order('jobs.id')
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
end
