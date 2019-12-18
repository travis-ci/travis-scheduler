class PullRequest < ActiveRecord::Base
  belongs_to :repository
  has_many :requests

  alias_attribute :head_repo_vcs_id, :head_repo_github_id
end
