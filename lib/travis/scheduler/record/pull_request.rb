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
    return head_git_url(repo)
    head_repository = Repository.find_by(vcs_slug: head_repo_slug)
    head_repository&.private? ? head_git_url(repo) : head_http_url(repo)
  end
end
