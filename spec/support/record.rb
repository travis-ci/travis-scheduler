# frozen_string_literal: true

Job.class_eval do
  def config=(config)
    super(JobConfig.new(key: 'key', config:, repository_id:))
  end
end
