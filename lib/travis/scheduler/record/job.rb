class Job < ActiveRecord::Base
  class << self
    def queueable
      if column_names.include?('queueable')
        where(queueable: true).order(:id)
      else
        where(state: :created).order(:id)
      end
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

  self.inheritance_column = :_disabled

  belongs_to :repository
  belongs_to :commit
  belongs_to :source, polymorphic: true, autosave: true
  belongs_to :owner, polymorphic: true

  serialize :config
  serialize :debug_options
end
