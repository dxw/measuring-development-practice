class PullRequest
  attr_accessor :number, :started_time, :opened_time, :merged_time,
    :number_of_commits, :total_line_changes, :number_of_reviews, :number_of_comments

  def initialize(number)
    @number = number
  end
end
