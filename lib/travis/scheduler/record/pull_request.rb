class PullRequest < ActiveRecord::Base
  belongs_to :repository
  has_many :requests

  def head_git_url(repo)
    repo.source_git_url(head_repo_slug)
  end

  def head_http_url(repo)
    repo.source_http_url(head_repo_slug)
  end

  def head_url(repo)
    puts "REPOSITORY IS #{repositoru}"
    repo.git_url? ? head_git_url(repo) : head_http_url(repo)
  end
end
