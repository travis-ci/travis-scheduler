# frozen_string_literal: true

class PullRequest < ActiveRecord::Base
  belongs_to :repository
  has_many :requests

  def head_url(repo)
    repo.source_git_url(head_repo_slug)
  end
end
