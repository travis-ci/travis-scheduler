# frozen_string_literal: true

class Queueable < ActiveRecord::Base
  self.table_name = :queueable_jobs
end
