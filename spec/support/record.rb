Job.class_eval do
  def config=(config)
    super(JobConfig.new(key: 'key', config: config, repository_id: repository_id))
  end
end

